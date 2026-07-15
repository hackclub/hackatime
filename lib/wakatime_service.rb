require "digest"

include ApplicationHelper
include ErrorReporting

class WakatimeService
  def initialize(user: nil, specific_filters: [], allow_cache: true, limit: 10, start_date: nil, end_date: nil, scope: nil, boundary_aware: false, valid_timestamps_only: false, exclude_categories: [], serving_filters: nil)
    @serving_filters = if serving_filters
      serving_filters.compact_blank.symbolize_keys
    elsif scope.nil?
      {}
    end
    @scope = scope || Clickhouse::Heartbeat.all
    @scope = @scope.with_valid_timestamps if valid_timestamps_only
    @scope = @scope.where.not("LOWER(category) IN (?)", exclude_categories) if exclude_categories.any?
    @exclude_categories = exclude_categories
    @user = user
    @boundary_aware = boundary_aware
    @scope = @scope.where(user_id: @user.id) if @user.present?

    @start_date = convert_to_unix_timestamp(start_date)
    @end_date = convert_to_unix_timestamp(end_date)

    # Default to 1 year ago if no start_date provided or if no data exists
    @start_date = @start_date || @scope.minimum(:time) || 1.year.ago.to_i
    @end_date = @end_date || @scope.maximum(:time) || Time.current.to_i

    @scope = @scope.where("time >= ? AND time < ?", @start_date, @end_date)

    @limit = limit
    @limit = nil if @limit&.zero?

    @specific_filters = specific_filters
    @allow_cache = allow_cache
    @raw_names = boundary_aware # test-mode parity: use raw key.presence names when boundary_aware
  end

  def generate_summary
    return cached_summary if @allow_cache

    build_summary
  end

  def cached_summary
    Rails.cache.fetch(summary_cache_key, expires_in: 1.minute) do
      build_summary
    end
  end

  def build_summary
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

    @serving_language_summary = if fused_language_summary_supported?
      stats_reader.language_summary(start_time: @start_date, end_time: @end_date)
    end

    @total_seconds = if @serving_language_summary
      @serving_language_summary.fetch(:total_seconds)
    elsif serving_summary_supported?
      stats_reader.total_seconds(start_time: @start_date, end_time: @end_date, filters: @serving_filters)
    elsif @boundary_aware
      Clickhouse::Heartbeat.duration_seconds_boundary_aware(@scope, @start_date, @end_date, excluded_categories: @exclude_categories) || 0
    else
      @scope.duration_seconds || 0
    end
    summary[:total_seconds] = @total_seconds

    @total_days = (@end_time - @start_time) / 86400
    summary[:daily_average] = @total_days.zero? ? 0 : @total_seconds / @total_days

    summary[:human_readable_total] = ApplicationController.helpers.short_time_detailed(@total_seconds)
    summary[:human_readable_daily_average] = ApplicationController.helpers.short_time_detailed(summary[:daily_average])

    summary[:languages] = generate_summary_chunk(:language) if @specific_filters.include?(:languages)
    summary[:projects] = generate_summary_chunk(:project) if @specific_filters.include?(:projects)

    summary
  end

  def summary_cache_key
    scope_digest = Digest::SHA256.hexdigest(@scope.to_sql)
    filters = @specific_filters.map(&:to_s).sort.join(",")

    [ "wakatime_service", "summary", "v1", scope_digest, filters, @limit ].join(":")
  end

  def generate_summary_chunk(group_by)
    if serving_summary_supported?
      return summary_chunk_from_durations(group_by, serving_durations(group_by))
    end

    summary_chunk_from_durations(group_by, @scope.group(group_by).duration_seconds)
  end

  def summary_chunk_from_durations(group_by, durations)
    result = []
    durations.each do |key, value|
      entry = {
        name: @raw_names ? (key.presence || "Other") : transform_display_name(group_by, key),
        total_seconds: value,
        text: ApplicationController.helpers.short_time_simple(value),
        hours: value / 3600,
        minutes: (value % 3600) / 60,
        percent: (100.0 * value / @total_seconds).round(2),
        digital: ApplicationController.helpers.digital_time(value)
      }
      entry[:color] = LanguageUtils.color(key) if group_by == :language
      result << entry
    end
    result = result.sort_by { |item| [ -item[:total_seconds], item[:name].to_s ] }
    result = result.first(@limit) if @limit.present?
    result
  end

  def self.parse_user_agent(user_agent)
    # Based on https://github.com/muety/wakapi/blob/b3668085c01dc0724d8330f4d51efd5b5aecaeb2/utils/http.go#L89

    # Regex pattern to match wakatime client user agents
    user_agent_pattern = /wakatime\/[^ ]+ \(([^)]+)\)(?: [^ ]+ ([^\/]+)(?:\/([^\/]+))?)?/

    return { os: "", editor: "", err: "failed to parse user agent string" } if user_agent.blank?

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

  def self.categorize_language(language)
    return nil if language.blank?

    LanguageUtils.display_name(language)
  end

  private

  def serving_summary_supported?
    return @serving_summary_supported if defined?(@serving_summary_supported)

    @serving_summary_supported = @user.present? && !@serving_filters.nil? &&
      !@boundary_aware && @exclude_categories.empty? && supported_serving_filters? &&
      day_boundary?(@start_date) && (day_boundary?(@end_date) || end_of_day_boundary?(@end_date))
  end

  def supported_serving_filters?
    return true if @serving_filters.empty?

    @serving_filters.keys == [ :project ] && Array(@serving_filters[:project]).one?
  end

  def stats_reader
    @stats_reader ||= Clickhouse::StatsReader.new(@user)
  end

  def serving_durations(group_by)
    project = Array(@serving_filters[:project]).first

    case group_by
    when :project
      return { project => stats_reader.total_seconds(start_time: @start_date, end_time: @end_date, filters: { project: project }) } if project

      stats_reader.project_durations(start_time: @start_date, end_time: @end_date)
    when :language
      if project
        @scope.group(:language).duration_seconds
      elsif @serving_language_summary
        @serving_language_summary.fetch(:languages)
      else
        stats_reader.filter_durations(dimension: :language, start_time: @start_date, end_time: @end_date)
      end
    else
      {}
    end
  end

  def day_boundary?(epoch)
    time = Time.at(epoch).utc
    time == time.beginning_of_day
  end

  def fused_language_summary_supported?
    serving_summary_supported? && @specific_filters.include?(:languages) && @serving_filters.empty?
  end

  def end_of_day_boundary?(epoch)
    time = Time.at(epoch).utc
    (time.to_f - time.end_of_day.to_f).abs < 1.001
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
