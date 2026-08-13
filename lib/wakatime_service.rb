require "digest"

include ApplicationHelper
include ErrorReporting

class WakatimeService
  def initialize(user: nil, specific_filters: [], allow_cache: true, limit: 10, start_date: nil, end_date: nil, scope: nil, boundary_aware: false, valid_timestamps_only: false, exclude_categories: [])
    @scope = scope || Heartbeat.all
    @scope = @scope.with_valid_timestamps if valid_timestamps_only
    @scope = @scope.where.not("LOWER(category) IN (?)", exclude_categories) if exclude_categories.any?
    @exclude_categories = exclude_categories
    @user = user
    @boundary_aware = boundary_aware

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
    @raw_names = boundary_aware # test-mode parity: use raw key.presence names when boundary_aware
  end

  def generate_summary
    return cached_summary if @allow_cache

    build_summary
  end

  def generate_daily_summaries(timezone:, start_date:, end_date:)
    activity_by_date = daily_activity(timezone)
    data = (start_date..end_date).map do |date|
      build_daily_summary(date, activity_by_date[date], timezone)
    end
    total_seconds = data.sum { |summary| summary.dig(:grand_total, :total_seconds) }
    active_days = data.count { |summary| summary.dig(:grand_total, :total_seconds).positive? }
    average_seconds = data.any? ? total_seconds / data.length : 0

    {
      data: data,
      cumulative_total: cumulative_duration(total_seconds),
      daily_average: {
        holidays: data.length - active_days,
        days_including_holidays: data.length,
        days_minus_holidays: active_days,
        seconds: average_seconds,
        seconds_including_other_language: average_seconds,
        text: duration_text(average_seconds),
        text_including_other_language: duration_text(average_seconds)
      },
      start: start_date.iso8601,
      end: end_date.iso8601
    }
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

    @total_seconds = if @boundary_aware
      Heartbeat.duration_seconds_boundary_aware(@scope, @start_date, @end_date, excluded_categories: @exclude_categories) || 0
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
    result = []
    @scope.group(group_by).duration_seconds.each do |key, value|
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
    result = result.sort_by { |item| -item[:total_seconds] }
    result = result.first(@limit) if @limit.present?
    result
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

  def daily_activity(timezone)
    activity_by_date = Hash.new do |hash, date|
      hash[date] = {
        total_seconds: 0,
        projects: Hash.new(0),
        ai_input_tokens: 0,
        ai_input_token_count: 0,
        ai_output_tokens: 0,
        ai_output_token_count: 0,
        ai_models: Hash.new(0)
      }
    end

    Heartbeat.daily_activity_summary_rows(scope: @scope, timezone: timezone).each do |row|
      activity = activity_by_date[row.fetch("local_date").to_date]
      duration = row.fetch("duration").to_i
      activity[:total_seconds] += duration
      activity[:projects][row["project"].presence || "Other"] += duration
      activity[:ai_input_tokens] += row.fetch("ai_input_tokens").to_i
      activity[:ai_input_token_count] += row.fetch("ai_input_token_count").to_i
      activity[:ai_output_tokens] += row.fetch("ai_output_tokens").to_i
      activity[:ai_output_token_count] += row.fetch("ai_output_token_count").to_i
      activity[:ai_models][row["ai_model"]] += row.fetch("ai_line_changes").to_i if row["ai_model"].present?
    end

    activity_by_date
  end

  def build_daily_summary(date, activity, timezone)
    activity ||= {
      total_seconds: 0,
      projects: {},
      ai_input_tokens: 0,
      ai_input_token_count: 0,
      ai_output_tokens: 0,
      ai_output_token_count: 0,
      ai_models: {}
    }
    total_seconds = activity[:total_seconds]
    grand_total = duration(total_seconds)
    grand_total[:ai_input_tokens] = activity[:ai_input_tokens] if activity[:ai_input_token_count].positive?
    grand_total[:ai_output_tokens] = activity[:ai_output_tokens] if activity[:ai_output_token_count].positive?
    if activity[:ai_models].any?
      grand_total[:ai_model_breakdown] = activity[:ai_models]
        .sort_by { |name, lines| [ -lines, name ] }
        .map { |name, lines| { name: name, lines: lines } }
    end

    day_start = date.beginning_of_day
    {
      grand_total: grand_total,
      branches: [],
      categories: [],
      dependencies: [],
      editors: [],
      entities: [],
      languages: [],
      machines: [],
      operating_systems: [],
      projects: project_breakdown(activity[:projects], total_seconds),
      range: {
        date: date.iso8601,
        start: day_start.utc.iso8601,
        end: day_start.end_of_day.utc.iso8601,
        text: summary_date_text(date),
        timezone: timezone
      }
    }
  end

  def project_breakdown(projects, total_seconds)
    projects.filter_map do |name, seconds|
      next unless seconds.positive?

      duration(seconds).merge(
        name: name,
        percent: total_seconds.positive? ? ((seconds.to_f / total_seconds) * 100).round(2) : 0
      )
    end.sort_by { |project| [ -project[:total_seconds], project[:name] ] }
  end

  def duration(total_seconds)
    total_seconds = total_seconds.to_i
    hours, remainder = total_seconds.divmod(3600)
    minutes, seconds = remainder.divmod(60)
    {
      total_seconds: total_seconds,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      digital: ApplicationController.helpers.digital_time(total_seconds),
      decimal: format("%.2f", total_seconds / 3600.0),
      text: duration_text(total_seconds)
    }
  end

  def cumulative_duration(total_seconds)
    value = duration(total_seconds)
    value[:seconds] = value.delete(:total_seconds)
    value
  end

  def duration_text(total_seconds)
    ApplicationController.helpers.short_time_detailed(total_seconds).presence || "0s"
  end

  def summary_date_text(date)
    today = Date.current
    return "Today" if date == today
    return "Yesterday" if date == today - 1.day

    date.to_fs(:long)
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
