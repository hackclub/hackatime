class DashboardStats
  FILTER_OPTIONS_CACHE_VERSION = "v1".freeze
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
    key = [ user ] + FILTERS.map { |field| params[field] } + [ interval.to_s, params[:from], params[:to] ]
    Rails.cache.fetch(key, expires_in: 5.minutes) { build_filterable_dashboard_data(interval) }
  end

  def activity_graph_data = live_activity_graph_data
  def today_stats_data = live_today_stats_data

  # ---- Building blocks ----------------------------------------------------
  # Public so tests (and ProfileStatsService) can inspect/override.

  def build_filterable_dashboard_data(interval)
    archived = user.project_repo_mappings.archived.pluck(:project_name)
    raw_filter_options = live_raw_filter_options
    result = query_result(raw_filter_options, archived)
    result[:selected_interval] = interval.to_s
    result[:selected_from] = params[:from].to_s
    result[:selected_to] = params[:to].to_s
    FILTERS.each { |field| result["selected_#{field}"] = params[field]&.split(",") || [] }
    result
  end

  def live_raw_filter_options
    cache_keys = FILTERS.index_with { |field| "user_#{user.id}_dashboard_filter_options_#{field}_#{FILTER_OPTIONS_CACHE_VERSION}" }
    reverse_lookup = cache_keys.invert

    cached = Rails.cache.fetch_multi(*cache_keys.values, expires_in: 15.minutes) do |cache_key|
      field = reverse_lookup.fetch(cache_key)
      rows = heartbeats_scope.where.not(field => nil).distinct.select(field).to_sql
      Clickhouse::Heartbeat.connection.select_all(rows).map { |row| row[field.to_s] }.compact_blank.sort
    rescue ActiveRecord::ActiveRecordError => e
      raise unless e.message.include?("undefined method 'map' for nil")

      []
    end

    cache_keys.transform_values { |cache_key| cached.fetch(cache_key, []) }
  end

  def query_result(raw_filter_options, archived)
    hb = heartbeats_scope
    result = filter_options_result(raw_filter_options, archived)
    h = ApplicationController.helpers

    Time.use_zone(user.timezone) do
      FILTERS.each do |field|
        next unless params[field].present?

        arr = params[field].split(",")
        hb = case field
        when :operating_system then hb.where(field => raw_filter_options.fetch(:operating_system, []).select { |value| arr.include?(h.display_os_name(value)) })
        when :editor then hb.where(field => raw_filter_options.fetch(:editor, []).select { |value| arr.include?(h.display_editor_name(value)) })
        when :language then hb.where(field => raw_filter_options.fetch(:language, []).select { |language| arr.include?(language.categorize_language) })
        else hb.where(field => arr)
        end
        result["singular_#{field}"] = arr.length == 1
      end

      hb = hb.filter_by_time_range(params[:interval], params[:from], params[:to])
      snapshot = DashboardData::Snapshots.aggregate_query_snapshot(user: user, scope: hb)
      DashboardData::Snapshots.fill_aggregate_result(result: result, snapshot: snapshot, archived: archived, helpers: h)
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

  def heartbeats_scope = Clickhouse::Heartbeat.for_user(user)
  def activity_graph_date_range(timezone) = DashboardData::Snapshots.activity_graph_date_range(timezone)
  def grouped_durations_snapshot(scope) = DashboardData::Snapshots.grouped_durations_snapshot(scope)
  def project_grouped_durations(scope) = DashboardData::Snapshots.project_grouped_durations(scope)
  def weekly_project_stats(scope, _timezone = user.timezone) = DashboardData::Snapshots.weekly_project_stats(user: user, scope: scope)
  def week_ranges = DashboardData::Snapshots.week_ranges(user.timezone)
  def today_stats_snapshot(scope) = DashboardData::Snapshots.today_stats_snapshot(user: user, scope: scope)

  def live_activity_graph_data
    timezone = user.timezone
    start_date, end_date = activity_graph_date_range(timezone)
    durations = Rails.cache.fetch(user.activity_graph_cache_key(timezone), expires_in: 1.minute) do
      Time.use_zone(timezone) { heartbeats_scope.daily_durations(user_timezone: timezone).to_h }
    end
    DashboardData::Snapshots.activity_graph_result(start_date: start_date, end_date: end_date, duration_by_date: durations, timezone: timezone)
  end

  def live_today_stats_data = DashboardData::Snapshots.today_stats_display(today_stats_snapshot(heartbeats_scope), helpers: ApplicationController.helpers)
end
