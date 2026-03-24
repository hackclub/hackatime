include ApplicationHelper
include ErrorReporting

class TestWakatimeService
  include WakatimeShared

  def initialize(user: nil, specific_filters: [], allow_cache: true, limit: 10, start_date: nil, end_date: nil, scope: nil, boundary_aware: false)
    @scope = scope || Heartbeat.all
    # trusting time from hackatime extensions.....
    # @scope = @scope.coding_only
    @scope = @scope.with_valid_timestamps

    # yeah macha we're removing unwated categories
    @scope = @scope.where.not("LOWER(category) IN (?)", [ "browsing", "ai coding", "meeting", "communicating" ])
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
  end

  def generate_summary
    return build_summary if Rails.env.test?
    return Rails.cache.fetch(summary_cache_key, expires_in: 5.minutes) { build_summary } if @allow_cache

    build_summary
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
      Heartbeat.duration_seconds_boundary_aware(@scope, @start_date, @end_date) || 0
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

  def generate_summary_chunk(group_by)
    result = []
    @scope.group(group_by).duration_seconds.each do |key, value|
      entry = {
        name: key.presence || "Other",
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

  private

  def summary_cache_key
    [
      self.class.name.underscore,
      @user&.id || "anonymous",
      @start_date,
      @end_date,
      @limit || "all",
      @specific_filters.sort.join(","),
      @boundary_aware,
      scope_cache_version,
      ActiveSupport::Digest.hexdigest(@scope.to_sql)
    ].join(":")
  end

  def scope_cache_version
    return HeartbeatCacheInvalidator.version_for(@user) if @user.present?

    @scope.maximum(:time).to_i
  end
end
