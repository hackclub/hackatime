include ApplicationHelper

class WakatimeService
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
  end

  def generate_summary
    summary = {}

    summary[:username] = @user.display_name if @user.present?
    summary[:user_id] = @user.id.to_s if @user.present?
    summary[:is_coding_activity_visible] = true if @user.present?
    summary[:is_other_usage_visible] = true if @user.present?
    summary[:status] = "ok"

    @start_time = @start_date
    @end_time = @end_date

    summary[:start] = Time.at(@start_time).strftime("%Y-%m-%dT%H:%M:%SZ")
    summary[:end] = Time.at(@end_time).strftime("%Y-%m-%dT%H:%M:%SZ")

    summary[:range] = "all_time"
    summary[:human_readable_range] = "All Time"

    @total_seconds = @scope.duration_seconds || 0
    summary[:total_seconds] = @total_seconds

    @total_days = (@end_time - @start_time) / 86400
    summary[:daily_average] = @total_days.zero? ? 0 : @total_seconds / @total_days

    summary[:human_readable_total] = ApplicationController.helpers.short_time_detailed(@total_seconds)
    summary[:human_readable_daily_average] = ApplicationController.helpers.short_time_detailed(summary[:daily_average])

    summary[:languages] = generate_summary_chunk(:language) if @specific_filters.include?(:languages)
    summary[:projects] = generate_summary_chunk(:project) if @specific_filters.include?(:projects)

    summary
  end

  def generate_summary_chunk(group_by)
    helpers = ApplicationController.helpers
    total_seconds = @total_seconds.to_f

    result = []
    @scope.group(group_by).duration_seconds.each do |key, value|
      percent_value = if total_seconds.positive?
        (100.0 * value / total_seconds).round(2)
      else
        0.0
      end

      result << {
        name: transform_display_name(group_by, key),
        total_seconds: value,
        text: helpers.short_time_simple(value),
        hours: value / 3600,
        minutes: (value % 3600) / 60,
        percent: percent_value,
        digital: helpers.digital_time(value)
      }
    end
    result = result.sort_by { |item| -item[:total_seconds] }
    result = result.first(@limit) if @limit.present?
    result
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
    Rails.logger.error("Error parsing user agent string: #{e.message}")
    { os: "", editor: "", err: "failed to parse user agent string" }
  end


  def transform_display_name(group_by, key)
    value = key.presence || "Other"
    case group_by
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

  private

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
    Rails.logger.error("Error converting timestamp: #{e.message}")
    nil
  end
end
