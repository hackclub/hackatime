class DashboardStats
  FILTER_OPTIONS_CACHE_VERSION = "v2".freeze
  WEEKLY_PROJECT_DIMENSION = "weekly_project".freeze
  FILTERS = %i[project language operating_system editor category].freeze

  attr_reader :user, :params

  def initialize(user:, params: ActionController::Parameters.new)
    @user = user
    @params = params
  end

  # ---- Public surface ------------------------------------------------------

  def filterable_dashboard_data
    interval = params[:interval]
    return build_filterable_dashboard_data(interval) if rollup_eligible?

    key = [ user, archived_project_names ] + FILTERS.map { |field| params[field] } + [ interval.to_s, params[:from], params[:to] ]
    Rails.cache.fetch(key, expires_in: 5.minutes) { build_filterable_dashboard_data(interval) }
  end

  def activity_graph_data
    row = rollup_fragment_row(DashboardRollup::ACTIVITY_GRAPH_DIMENSION)
    return activity_graph_from_rollup(row) if activity_graph_rollup_valid?(row)
    schedule_rollup_refresh(wait: 0.seconds) if rollups_available?
    live_activity_graph_data
  end

  def today_stats_data
    row = rollup_fragment_row(DashboardRollup::TODAY_STATS_DIMENSION)
    return today_stats_from_rollup(row) if today_stats_rollup_valid?(row)
    schedule_rollup_refresh(wait: 0.seconds) if rollups_available?
    live_today_stats_data
  end

  # ---- Building blocks ----------------------------------------------------
  # Public so tests (and ProfileStatsService) can inspect/override.

  def build_filterable_dashboard_data(interval)
    archived = archived_project_names
    raw_filter_options = raw_filter_options(archived: archived)
    result = rollup_result(raw_filter_options, archived) || query_result(raw_filter_options, archived)
    result[:selected_interval] = interval.to_s
    result[:selected_from] = params[:from].to_s
    result[:selected_to] = params[:to].to_s
    result[:coding_time_average] = coding_time_average(result[:total_time], interval, filter_options: raw_filter_options)
    FILTERS.each { |field| result["selected_#{field}"] = params[field]&.split(",") || [] }
    result
  end

  def coding_time_average(total_seconds, interval, filter_options: nil)
    period = coding_time_average_period(interval, filter_options: filter_options)
    return unless period

    start_date, end_date, label = period
    day_count = [ (end_date - start_date).to_i + 1, 1 ].max
    {
      average_seconds: total_seconds.to_f / day_count,
      total_seconds: total_seconds,
      day_count: day_count,
      period_label: label
    }
  end

  def coding_time_average_period(interval, filter_options: nil)
    interval = interval.to_s
    return if interval.blank? || interval == "today"

    Time.use_zone(user.timezone) do
      if Heartbeat::RANGES.key?(interval.to_sym)
        config = Heartbeat::RANGES.fetch(interval.to_sym)
        range = config.fetch(:calculate).call
        start_date = range.begin.to_date
        end_date = [ range.end.to_date, Date.current ].min
        [ start_date, end_date, config.fetch(:human_name) ] if start_date <= end_date
      else
        custom_coding_time_average_period(filter_options: filter_options)
      end
    end
  end

  def custom_coding_time_average_period(filter_options: nil)
    from = Date.parse(params[:from]) if params[:from].present?
    to = Date.parse(params[:to]) if params[:to].present?
    return unless from || to

    from ||= first_dashboard_heartbeat_date(filter_options: filter_options) || to
    to = [ to || Date.current, Date.current ].min
    return if from > to

    label = if params[:from].present? && params[:to].present?
      "#{params[:from]} to #{params[:to]}"
    elsif params[:from].present?
      "From #{params[:from]}"
    else
      "Until #{params[:to]}"
    end
    [ from, to, label ]
  rescue Date::Error
    nil
  end

  def first_dashboard_heartbeat_date(filter_options: nil)
    filter_options ||= raw_filter_options(archived: archived_project_names)
    timestamp = filtered_dashboard_heartbeats(filter_options).with_valid_timestamps.minimum(:time)
    Time.zone.at(timestamp).to_date if timestamp
  end

  def raw_filter_options(archived: [])
    (rollup_eligible? && rollup_filter_options) || live_raw_filter_options
  end

  def live_raw_filter_options
    archive_key = ActiveSupport::Digest.hexdigest(archived_project_names.to_json)
    cache_keys = FILTERS.index_with { |field| "user_#{user.id}_dashboard_filter_options_#{field}_#{FILTER_OPTIONS_CACHE_VERSION}_#{archive_key}" }
    reverse_lookup = cache_keys.invert

    cached = Rails.cache.fetch_multi(*cache_keys.values, expires_in: 15.minutes) do |cache_key|
      dashboard_heartbeats.distinct.pluck(reverse_lookup.fetch(cache_key)).compact_blank
    end

    cache_keys.transform_values { |cache_key| cached.fetch(cache_key, []) }
  end

  def rollup_filter_options
    return unless rollups_available?

    row = rollup_fragment_row(DashboardRollup::FILTER_OPTIONS_DIMENSION)
    payload = row&.payload
    unless payload.is_a?(Hash) && FILTERS.all? { |field| payload[field.to_s].is_a?(Array) || payload[field].is_a?(Array) }
      schedule_rollup_refresh(wait: 0.seconds)
      return
    end

    FILTERS.index_with { |field| Array(payload[field.to_s] || payload[field]) }
  end

  def query_result(raw_filter_options, archived)
    result = filter_options_result(raw_filter_options, archived)
    h = ApplicationController.helpers

    Time.use_zone(user.timezone) do
      hb = filtered_dashboard_heartbeats(raw_filter_options, result: result)
      hb = hb.filter_by_time_range(params[:interval], params[:from], params[:to])
      snapshot = DashboardData::Snapshots.aggregate_query_snapshot(user: user, scope: hb)
      DashboardData::Snapshots.fill_aggregate_result(result: result, snapshot: snapshot, archived: archived, helpers: h)
    end

    result
  end

  def filtered_dashboard_heartbeats(filter_options, result: nil)
    helpers = ApplicationController.helpers

    FILTERS.each_with_object(dashboard_heartbeats) do |field, heartbeats|
      next unless params[field].present?

      selected = params[field].split(",")
      values = case field
      when :operating_system then filter_options.fetch(field, []).select { |value| selected.include?(helpers.display_os_name(value)) }
      when :editor then filter_options.fetch(field, []).select { |value| selected.include?(helpers.display_editor_name(value)) }
      when :language then filter_options.fetch(field, []).select { |value| selected.include?(value.categorize_language) }
      else selected
      end
      heartbeats.where!(field => values)
      result["singular_#{field}"] = selected.one? if result
    end
  end

  def rollup_result(raw_filter_options, archived)
    snapshot = aggregate_rollup_snapshot
    return unless snapshot

    result = filter_options_result(raw_filter_options, archived)
    Time.use_zone(user.timezone) do
      DashboardData::Snapshots.fill_aggregate_result(result: result, snapshot: snapshot, archived: archived, helpers: ApplicationController.helpers)
    end
    result
  end

  def filter_options_result(raw_filter_options, archived)
    h = ApplicationController.helpers
    FILTERS.each_with_object({}) do |field, result|
      options = raw_filter_options.fetch(field, [])
      options = options.reject { |name| archived.include?(name) || ProjectNameUtils.broken?(name) } if field == :project
      result[field] = options.map { |value|
        case field
        when :language then value.categorize_language
        when :editor then h.display_editor_name(value)
        when :operating_system then h.display_os_name(value)
        else value
        end
      }.uniq
    end
  end

  def aggregate_rollup_snapshot
    return unless rollups_available? && rollup_eligible?

    total_row = rollup_total_row
    unless total_row
      schedule_rollup_refresh(wait: 0.seconds)
      return
    end
    schedule_rollup_refresh(wait: 0.seconds) if aggregate_rollup_stale?(total_row)

    {
      total_time: total_row.total_seconds,
      total_heartbeats: total_row.source_heartbeats_count.to_i,
      grouped_durations: FILTERS.index_with { |field|
        rollup_rows_by_dimension.fetch(field.to_s, []).to_h { |row| [ row.bucket, row.total_seconds ] }
      },
      weekly_project_stats: rollup_weekly_project_stats(rollup_rows_by_dimension.fetch(WEEKLY_PROJECT_DIMENSION, [])),
      coding_rhythm: aggregate_rollup_coding_rhythm
    }
  end

  def rollup_eligible?
    params[:interval].blank? && params[:from].blank? && params[:to].blank? &&
      FILTERS.none? { |field| params[field].present? }
  end

  def rollups_available?
    DashboardRollup.table_exists?
  rescue ActiveRecord::StatementInvalid
    false
  end

  def rollup_rows
    return [] unless rollups_available?
    @rollup_rows ||= DashboardRollup.where(user_id: user.id).to_a
  end

  def rollup_rows_by_dimension = @rollup_rows_by_dimension ||= rollup_rows.group_by(&:dimension)
  def rollup_fragment_row(dimension) = rollup_rows_by_dimension.fetch(dimension.to_s, []).first
  def rollup_total_row = @rollup_total_row ||= rollup_rows.find(&:total_dimension?)
  def rollup_source_max_heartbeat_time = rollup_time_fingerprint(dashboard_heartbeats.maximum(:time))
  def rollup_time_fingerprint(timestamp) = timestamp.nil? ? nil : (timestamp * 1_000_000).round
  def today_date = Time.use_zone(user.timezone) { Date.current.iso8601 }
  def activity_graph_date_range(timezone) = DashboardData::Snapshots.activity_graph_date_range(timezone)
  def grouped_durations_snapshot(scope) = DashboardData::Snapshots.grouped_durations_snapshot(scope)
  def project_grouped_durations(scope) = DashboardData::Snapshots.project_grouped_durations(scope)
  def weekly_project_stats(scope, _timezone = user.timezone) = DashboardData::Snapshots.weekly_project_stats(user: user, scope: scope)
  def week_ranges = DashboardData::Snapshots.week_ranges(user.timezone)
  def today_stats_snapshot(scope) = DashboardData::Snapshots.today_stats_snapshot(user: user, scope: scope)

  def aggregate_rollup_coding_rhythm
    row = rollup_fragment_row(DashboardRollup::CODING_RHYTHM_DIMENSION)
    payload = row&.payload
    return payload if payload.is_a?(Hash) && payload["timezone"] == user.timezone && payload["duration_by_slot"].is_a?(Hash)

    schedule_rollup_refresh(wait: 0.seconds)
    DashboardData::Snapshots.coding_rhythm_snapshot(user: user, scope: dashboard_heartbeats)
  end

  def aggregate_rollup_stale?(total_row)
    rollups_dirty? ||
      rollup_time_fingerprint(total_row.source_max_heartbeat_time) != rollup_source_max_heartbeat_time
  end

  def schedule_rollup_refresh(wait:)
    return if @rollup_refresh_scheduled
    DashboardRollupRefreshJob.schedule_for(user.id, wait: wait)
    @rollup_refresh_scheduled = true
  end

  def activity_graph_rollup_valid?(row)
    return false if rollups_dirty?
    payload = row&.payload
    return false unless payload.is_a?(Hash)
    start_date, end_date = activity_graph_date_range(user.timezone)
    payload["timezone"] == user.timezone && payload["start_date"] == start_date &&
      payload["end_date"] == end_date && payload["duration_by_date"].is_a?(Hash)
  end

  def today_stats_rollup_valid?(row)
    return false if rollups_dirty?
    payload = row&.payload
    return false unless payload.is_a?(Hash)
    payload["timezone"] == user.timezone && payload["today_date"] == today_date &&
      payload.key?("todays_duration_seconds") &&
      payload["todays_language_categories"].is_a?(Array) &&
      payload["todays_editor_keys"].is_a?(Array)
  end

  def live_activity_graph_data
    timezone = user.timezone
    start_date, end_date = activity_graph_date_range(timezone)
    cache_key = [ user.activity_graph_cache_key(timezone), "without_archived_v1", archived_project_names ]
    durations = Rails.cache.fetch(cache_key, expires_in: 1.minute) do
      Time.use_zone(timezone) { dashboard_heartbeats.daily_durations(user_timezone: timezone).to_h }
    end
    DashboardData::Snapshots.activity_graph_result(start_date: start_date, end_date: end_date, duration_by_date: durations, timezone: timezone)
  end

  def activity_graph_from_rollup(row)
    payload = row.payload || {}
    DashboardData::Snapshots.activity_graph_result(
      start_date: payload["start_date"], end_date: payload["end_date"],
      duration_by_date: payload["duration_by_date"], timezone: payload["timezone"] || user.timezone
    )
  end

  def live_today_stats_data = DashboardData::Snapshots.today_stats_display(today_stats_snapshot(dashboard_heartbeats), helpers: ApplicationController.helpers)
  def today_stats_from_rollup(row) = DashboardData::Snapshots.today_stats_display(row.payload, helpers: ApplicationController.helpers)

  def rollup_weekly_project_stats(rows)
    result = week_ranges.to_h { |week_key, *_| [ week_key, {} ] }
    rows.each do |row|
      week_key, project = JSON.parse(row.bucket_value)
      result[week_key][project] = row.total_seconds if result.key?(week_key)
    end
    result
  end

  def archived_project_names = @archived_project_names ||= user.project_repo_mappings.archived.order(:project_name).pluck(:project_name)
  def dashboard_heartbeats = user.heartbeats_excluding_archived_projects

  def rollups_dirty?
    return @rollups_dirty if defined?(@rollups_dirty)
    @rollups_dirty = DashboardRollup.dirty?(user.id)
  end
end
