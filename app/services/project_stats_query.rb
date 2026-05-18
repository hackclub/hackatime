class ProjectStatsQuery
  def initialize(user:, params:, include_archived: false, default_discovery_start: 30.days.ago.beginning_of_day, default_discovery_end: Time.current, default_stats_start: 1.year.ago, default_stats_end: Time.current)
    @user = user
    @params = normalize_params(params)
    @include_archived = include_archived
    @default_discovery_start = default_discovery_start
    @default_discovery_end = default_discovery_end
    @default_stats_start = default_stats_start
    @default_stats_end = default_stats_end
  end

  def project_names
    names = scoped_heartbeats(discovery_start_time, discovery_end_time)
            .select(:project)
            .distinct
            .pluck(:project)
            .compact

    return names if @include_archived

    names.reject { |name| archived_project_names.include?(name) }
  end

  def project_details(names: nil)
    requested_names = normalize_names(names)

    if requested_names.empty? && rollup_eligible?
      rollup_details = rollup_project_details
      return rollup_details if rollup_details
    end

    query = scoped_heartbeats(stats_start_time, stats_end_time)
    query = query.where(project: requested_names) if requested_names.any?

    stats = DashboardData::Snapshots.project_details_snapshot(scope: query)
    return [] if stats.empty?

    candidate_names = requested_names.presence || stats.keys
    repo_mappings = @user.project_repo_mappings
                         .where(project_name: candidate_names)
                         .index_by(&:project_name)

    selected_names = candidate_names.reject do |name|
      !@include_archived && repo_mappings[name]&.archived?
    end
    selected_names.filter_map do |name|
      stat = stats[name]
      next unless stat

      repo_mapping = repo_mappings[name]
      archived = repo_mapping&.archived? || false

      first_heartbeat = format_heartbeat_time(stat[:first_heartbeat])
      last_heartbeat = format_heartbeat_time(stat[:last_heartbeat])

      {
        name: name,
        total_seconds: stat[:total_seconds],
        languages: stat[:languages] || [],
        repo_url: repo_mapping&.repo_url,
        total_heartbeats: stat[:total_heartbeats],
        first_heartbeat: first_heartbeat,
        last_heartbeat: last_heartbeat,
        most_recent_heartbeat: last_heartbeat,
        archived: archived
      }
    end.sort_by { |project| -project[:total_seconds] }
  end

  private

  def normalize_params(params)
    h = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
    h.with_indifferent_access
  end

  def normalize_names(names)
    raw = names.presence || parse_csv(@params[:projects])
    Array(raw).map(&:to_s).map(&:strip).reject(&:blank?).uniq
  end

  def scoped_heartbeats(start_time, end_time)
    start_timestamp = timestamp_value(start_time)
    end_timestamp = timestamp_value(end_time)
    return @user.heartbeats.none if start_timestamp.nil? || end_timestamp.nil?

    @user.heartbeats
         .with_valid_timestamps
         .where.not(project: [ nil, "" ])
         .where(time: start_timestamp..end_timestamp)
  end

  def archived_project_names
    @archived_project_names ||= @user.project_repo_mappings.archived.pluck(:project_name)
  end

  def rollup_project_details
    project_detail_rows = DashboardRollup
      .where(user_id: @user.id, dimension: DashboardRollup::PROJECT_DETAILS_DIMENSION, bucket_value_present: true)
      .to_a
    return if project_detail_rows.empty?

    DashboardRollupRefreshJob.schedule_for(@user.id, wait: 0.seconds) if DashboardRollup.dirty?(@user.id)

    details_by_project = project_detail_rows.index_by(&:bucket)
    details_by_project.delete("")
    return if details_by_project.empty?

    repo_mappings = @user.project_repo_mappings
      .where(project_name: details_by_project.keys)
      .index_by(&:project_name)

    selected_names = details_by_project.keys.reject do |name|
      !@include_archived && repo_mappings[name]&.archived?
    end

    selected_names.filter_map do |name|
      rollup = details_by_project[name]
      payload = rollup.payload.to_h

      repo_mapping = repo_mappings[name]
      first_heartbeat = format_heartbeat_time(payload["first_heartbeat"])
      last_heartbeat = format_heartbeat_time(payload["last_heartbeat"])

      {
        name: name,
        total_seconds: rollup.total_seconds.to_i,
        languages: Array(payload["languages"]).compact_blank,
        repo_url: repo_mapping&.repo_url,
        total_heartbeats: rollup.source_heartbeats_count.to_i,
        first_heartbeat: first_heartbeat,
        last_heartbeat: last_heartbeat,
        most_recent_heartbeat: last_heartbeat,
        archived: repo_mapping&.archived? || false
      }
    end.sort_by { |project| -project[:total_seconds] }
  end

  def rollup_eligible?
    @params[:projects].blank? &&
      %i[start start_date end end_date].none? { |key| @params[key].present? } &&
      timestamp_value(@default_stats_start).to_f.zero?
  end

  def discovery_start_time
    parse_time([ :since, :start, :start_date ], default: @default_discovery_start)
  end

  def discovery_end_time
    parse_time([ :until, :until_date, :end, :end_date ], default: @default_discovery_end)
  end

  def stats_start_time
    parse_time([ :start, :start_date ], default: @default_stats_start)
  end

  def stats_end_time
    parse_time([ :end, :end_date ], default: @default_stats_end)
  end

  def parse_time(keys, default:)
    keys.each do |key|
      parsed = parse_datetime(@params[key])
      return parsed if parsed
    end

    default
  end

  def parse_datetime(value)
    return nil if value.blank?

    value.to_datetime
  rescue ArgumentError, TypeError
    nil
  end

  def parse_csv(value)
    return [] if value.blank?

    value.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  def format_heartbeat_time(time_value)
    return nil if time_value.blank?

    Time.at(time_value.to_f).utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  end

  def timestamp_value(value)
    case value
    when Numeric
      value.to_f
    when Time, ActiveSupport::TimeWithZone
      value.to_f
    when DateTime
      value.to_time.to_f
    end
  end
end
