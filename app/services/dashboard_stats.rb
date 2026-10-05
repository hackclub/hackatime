class DashboardStats
  FILTER_OPTIONS_CACHE_VERSION = "v4".freeze
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

    key = [ "attributed_dashboard_v1", user, user.heartbeat_cache_version, archived_project_names ] + FILTERS.map { |field| params[field] } + [ interval.to_s, params[:from], params[:to] ]
    Rails.cache.fetch(key, expires_in: 5.minutes) { build_filterable_dashboard_data(interval) }
  end

  def activity_graph_data
    snapshot = rollup_snapshot
    return DashboardData::Snapshots.activity_graph_result(**snapshot.fetch(:activity_graph)) if snapshot

    live_activity_graph_data
  end

  def today_stats_data
    snapshot = rollup_snapshot
    payload = snapshot ? snapshot.fetch(:today_stats) : today_stats_snapshot(dashboard_heartbeats)
    DashboardData::Snapshots.today_stats_display(payload, helpers: ApplicationController.helpers)
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
    cache_key = "user_#{user.id}_dashboard_filter_options_#{FILTER_OPTIONS_CACHE_VERSION}_#{archive_key}_#{user.heartbeat_cache_version}"

    Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      values = dashboard_heartbeats.pick(*FILTERS.map { |field| Arel.sql("groupUniqArray(#{field})") })
      FILTERS.zip(values).to_h { |field, options| [ field, Array(options).compact_blank.sort ] }
    end
  end

  def rollup_filter_options = rollup_snapshot&.fetch(:filter_options)

  def query_result(raw_filter_options, archived)
    result = filter_options_result(raw_filter_options, archived)
    h = ApplicationController.helpers

    Time.use_zone(user.timezone) do
      hb = dashboard_heartbeats.filter_by_time_range(params[:interval], params[:from], params[:to])
      snapshot = if FILTERS.any? { |field| params[field].present? }
        DashboardData::Snapshots.adaptive_filtered_snapshot(user: user, scope: hb) do |scope|
          filtered_dashboard_heartbeats(raw_filter_options, result: result, scope: scope)
        end
      else
        DashboardData::Snapshots.aggregate_query_snapshot(user: user, scope: hb)
      end
      DashboardData::Snapshots.fill_aggregate_result(result: result, snapshot: snapshot, archived: archived, helpers: h)
    end

    result
  end

  def filtered_dashboard_heartbeats(filter_options, result: nil, scope: dashboard_heartbeats)
    helpers = ApplicationController.helpers

    FILTERS.each_with_object(scope) do |field, heartbeats|
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
    snapshot = rollup_eligible? && rollup_snapshot
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

  def rollup_eligible?
    params[:interval].blank? && params[:from].blank? && params[:to].blank? &&
      FILTERS.none? { |field| params[field].present? }
  end

  # The user's published heartbeat rollup, or nil (and a rebuild is scheduled)
  # when there is no rollup that is current for their timezone and exclusions.
  def rollup_snapshot
    return @rollup_snapshot if defined?(@rollup_snapshot)

    state = HeartbeatRollupState.current_for(user)
    DashboardRollupRefreshJob.schedule_for(user.id, wait: 0.seconds) unless state
    @rollup_snapshot = state && HeartbeatRollup.dashboard_snapshot(state)
  end

  def activity_graph_date_range(timezone) = DashboardData::Snapshots.activity_graph_date_range(timezone)
  def today_stats_snapshot(scope) = DashboardData::Snapshots.today_stats_snapshot(user: user, scope: scope)

  def live_activity_graph_data
    timezone = user.timezone
    start_date, end_date = activity_graph_date_range(timezone)
    cache_key = [ user.activity_graph_cache_key(timezone), "without_archived_v1", archived_project_names ]
    durations = Rails.cache.fetch(cache_key, expires_in: 1.minute) do
      Time.use_zone(timezone) { dashboard_heartbeats.daily_durations(user_timezone: timezone).to_h }
    end
    DashboardData::Snapshots.activity_graph_result(start_date: start_date, end_date: end_date, duration_by_date: durations, timezone: timezone)
  end

  def archived_project_names = @archived_project_names ||= user.project_repo_mappings.archived.order(:project_name).pluck(:project_name)
  def dashboard_heartbeats = user.heartbeats_excluding_archived_projects
end
