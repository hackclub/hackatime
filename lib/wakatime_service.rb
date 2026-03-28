include ApplicationHelper
include ErrorReporting

class WakatimeService
  SUPPORTED_FILTERS = {
    languages: "language",
    projects: "project"
  }.freeze

  def initialize(user: nil, specific_filters: [], allow_cache: true, limit: 10, start_date: nil, end_date: nil, scope: nil)
    @scope = scope || Heartbeat.all
    @user = user

    @start_date = convert_to_unix_timestamp(start_date)
    @end_date = convert_to_unix_timestamp(end_date)

    # Default to 1 year ago if no start_date provided or if no data exists
    @start_date = @start_date || @scope.minimum(:time) || 1.year.ago.to_i
    @end_date = @end_date || @scope.maximum(:time) || Time.current.to_i

    @scope = @scope.where("time >= ? AND time < ?", @start_date, @end_date)

    @limit = limit
    @limit = nil if @limit&.zero?

    @scope = @scope.where(user_id: @user.id) if @user.present?

    @specific_filters = specific_filters
    @allow_cache = allow_cache
    @project_filter = extract_project_filter(scope)
  end

  def generate_summary
    result = StatsClient.summary(
      user_id: @user&.id,
      start_time: @start_date,
      end_time: @end_date,
      group_by: requested_group_bys.presence,
      limit: @limit,
      projects: @project_filter
    )

    format_summary(result)
  end

  def self.parse_user_agent(user_agent)
    # Based on https://github.com/muety/wakapi/blob/b3668085c01dc0724d8330f4d51efd5b5aecaeb2/utils/http.go#L89

    # Regex pattern to match wakatime client user agents
    user_agent_pattern = /wakatime\/[^ ]+ \(([^)]+)\)(?: [^ ]+ ([^\/]+)(?:\/([^\/]+))?)?/

    if matches = user_agent.match(user_agent_pattern)
      os = matches[1].split("-").first

      editor = matches[2]
      editor ||= ""

      { os: os, editor: editor, err: nil }
    else
      # Try parsing as browser user agent as fallback
      if browser_ua = user_agent.match(/^([^\/]+)\/([^\/\s]+)/)
        # If "wakatime" is present, assume it's the browser extension
        if user_agent.include?("wakatime") then
            full_os = user_agent.split(" ")[1]
            if full_os.present?
              os = full_os.include?("_") ? full_os.split("_")[0] : full_os
              { os: os, editor: browser_ua[1].downcase, err: nil }
            else
              { os: "", editor: "", err: "failed to parse user agent string" }
            end
        else
          { os: browser_ua[1], editor: browser_ua[2], err: nil }
        end
      else
        { os: "", editor: "", err: "failed to parse user agent string" }
      end
    end
  rescue => e
    report_error(e, message: "Error parsing user agent string")
    { os: "", editor: "", err: "failed to parse user agent string" }
  end

  def transform_display_name(group_by, key)
    value = key.presence || "Other"
    case group_by.to_sym
    when :editor
      ApplicationController.helpers.display_editor_name(value)
    when :operating_system
      ApplicationController.helpers.display_os_name(value)
    when :language
      ApplicationController.helpers.display_language_name(value)
    else
      value
    end
  end

  def self.categorize_language(language)
    return nil if language.blank?

    LanguageUtils.display_name(language)
  end

  private

  def format_summary(result)
    summary = {}

    summary[:username] = @user.display_name if @user.present?
    summary[:user_id] = @user.id.to_s if @user.present?
    summary[:is_coding_activity_visible] = true if @user.present?
    summary[:is_other_usage_visible] = true if @user.present?
    summary[:status] = "ok"

    @start_time = result["start_time"].to_i
    @end_time = result["end_time"].to_i

    summary[:start] = Time.at(@start_time).strftime("%Y-%m-%dT%H:%M:%SZ")
    summary[:end] = Time.at(@end_time).strftime("%Y-%m-%dT%H:%M:%SZ")

    summary[:range] = "all_time"
    summary[:human_readable_range] = "All Time"

    @total_seconds = result["total_seconds"].to_i
    summary[:total_seconds] = @total_seconds

    @total_days = (@end_time - @start_time) / 86400
    summary[:daily_average] = @total_days.zero? ? 0 : @total_seconds / @total_days

    summary[:human_readable_total] = ApplicationController.helpers.short_time_detailed(@total_seconds)
    summary[:human_readable_daily_average] = ApplicationController.helpers.short_time_detailed(summary[:daily_average])

    SUPPORTED_FILTERS.each do |summary_key, group_by|
      next unless @specific_filters.include?(summary_key)

      summary[summary_key] = generate_summary_chunk(group_by, result.dig("groups", group_by) || [])
    end

    summary
  end

  def generate_summary_chunk(group_by, groups)
    result = groups.map do |group|
      key = group["name"]
      value = group["total_seconds"].to_i
      entry = {
        name: transform_display_name(group_by, key),
        total_seconds: value,
        text: ApplicationController.helpers.short_time_simple(value),
        hours: value / 3600,
        minutes: (value % 3600) / 60,
        percent: group["percent"].to_f.round(2),
        digital: ApplicationController.helpers.digital_time(value)
      }
      entry[:color] = LanguageUtils.color(key) if group_by == "language"
      entry
    end

    result = result.sort_by { |item| -item[:total_seconds] }
    result = result.first(@limit) if @limit.present?
    result
  end

  def requested_group_bys
    @specific_filters.filter_map { |filter| SUPPORTED_FILTERS[filter.to_sym] }
  end

  def extract_project_filter(scope)
    value = scope&.where_values_hash&.with_indifferent_access&.dig(:project)
    Array.wrap(value).presence
  end

  def convert_to_unix_timestamp(timestamp)
    # our lord and savior stack overflow for this bit of code
    return nil if timestamp.nil?

    case timestamp
    when String
      Time.parse(timestamp).to_i
    when Time, DateTime, Date
      timestamp.to_i
    when Numeric
      timestamp.to_i
    else
      nil
    end
  rescue ArgumentError => e
    report_error(e, message: "Error converting timestamp")
    nil
  end
end
