class ProjectStatsQuery
  def initialize(
    user:,
    params:,
    include_archived: false,
    default_discovery_start: 30.days.ago.beginning_of_day,
    default_discovery_end: Time.current,
    default_stats_start: 1.year.ago,
    default_stats_end: Time.current
  )
    @user = user
    @params = (params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h).with_indifferent_access
    @include_archived = include_archived
    @default_discovery_start = default_discovery_start
    @default_discovery_end = default_discovery_end
    @default_stats_start = default_stats_start
    @default_stats_end = default_stats_end
  end

  def project_names
    names = scoped_heartbeats(discovery_start_time, discovery_end_time).select(:project).distinct.pluck(:project).compact
    @include_archived ? names : names.reject { |name| archived_project_names.include?(name) }
  end

  def project_details(names: nil)
    requested_names = Array(names.presence || parse_csv(@params[:projects]))
                       .map { |n| n.to_s.strip }.reject(&:blank?).uniq

    if requested_names.empty? && rollup_eligible? && (rollup_details = rollup_project_details)
      return rollup_details
    end

    query = scoped_heartbeats(stats_start_time, stats_end_time)
    query = query.where(project: requested_names) if requested_names.any?

    stats = DashboardData::Snapshots.project_details_snapshot(scope: query)
    return [] if stats.empty?

    candidate_names = requested_names.presence || stats.keys
    repo_mappings = @user.project_repo_mappings.where(project_name: candidate_names).index_by(&:project_name)

    candidate_names.filter_map { |name|
      next if !@include_archived && repo_mappings[name]&.archived?
      stat = stats[name]
      next unless stat
      build_project_row(name: name, stat: stat, repo_mapping: repo_mappings[name])
    }.sort_by { |project| -project[:total_seconds] }
  end

  private

  def build_project_row(
    name:,
    stat:,
    repo_mapping:,
    total_seconds: nil,
    total_heartbeats: nil,
    languages: nil,
    first_heartbeat: nil,
    last_heartbeat: nil
  )
    first_iso = format_heartbeat_time(first_heartbeat || stat[:first_heartbeat])
    last_iso = format_heartbeat_time(last_heartbeat || stat[:last_heartbeat])
    {
      name: name,
      total_seconds: total_seconds || stat[:total_seconds],
      languages: languages || stat[:languages] || [],
      repo_url: repo_mapping&.repo_url,
      total_heartbeats: total_heartbeats || stat[:total_heartbeats],
      first_heartbeat: first_iso,
      last_heartbeat: last_iso,
      most_recent_heartbeat: last_iso,
      archived: repo_mapping&.archived? || false
    }
  end

  def scoped_heartbeats(start_time, end_time)
    start_ts = timestamp_value(start_time)
    end_ts = timestamp_value(end_time)
    return @user.heartbeats.none if start_ts.nil? || end_ts.nil?

    @user.heartbeats.with_valid_timestamps.where.not(project: [ nil, "" ]).where(time: start_ts..end_ts)
  end

  def archived_project_names
    @archived_project_names ||= @user.project_repo_mappings.archived.pluck(:project_name)
  end

  def rollup_project_details
    rows = DashboardRollup.where(user_id: @user.id, dimension: DashboardRollup::PROJECT_DETAILS_DIMENSION, bucket_value_present: true).to_a
    return if rows.empty?

    DashboardRollupRefreshJob.schedule_for(@user.id, wait: 0.seconds) if DashboardRollup.dirty?(@user.id)

    details_by_project = rows.index_by(&:bucket)
    details_by_project.delete("")
    return if details_by_project.empty?

    repo_mappings = @user.project_repo_mappings.where(project_name: details_by_project.keys).index_by(&:project_name)

    details_by_project.filter_map { |name, rollup|
      next if !@include_archived && repo_mappings[name]&.archived?
      payload = rollup.payload.to_h
      build_project_row(
        name: name, stat: {}, repo_mapping: repo_mappings[name],
        total_seconds: rollup.total_seconds.to_i,
        total_heartbeats: rollup.source_heartbeats_count.to_i,
        languages: Array(payload["languages"]).compact_blank,
        first_heartbeat: payload["first_heartbeat"],
        last_heartbeat: payload["last_heartbeat"]
      )
    }.sort_by { |project| -project[:total_seconds] }
  end

  def rollup_eligible?
    @params[:projects].blank? &&
      %i[start start_date end end_date].none? { |key| @params[key].present? } &&
      timestamp_value(@default_stats_start).to_f.zero?
  end

  def discovery_start_time = parse_time([ :since, :start, :start_date ], default: @default_discovery_start)
  def discovery_end_time = parse_time([ :until, :until_date, :end, :end_date ], default: @default_discovery_end)
  def stats_start_time = parse_time([ :start, :start_date ], default: @default_stats_start)
  def stats_end_time = parse_time([ :end, :end_date ], default: @default_stats_end)

  def parse_time(keys, default:)
    keys.each do |key|
      value = @params[key]
      next if value.blank?
      return value.to_datetime
    rescue ArgumentError, TypeError
      next
    end
    default
  end

  def parse_csv(value)
    value.blank? ? [] : value.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  def format_heartbeat_time(time_value)
    Time.at(time_value.to_f).utc.strftime("%Y-%m-%dT%H:%M:%SZ") if time_value.present?
  end

  def timestamp_value(value)
    case value
    when Numeric then value.to_f
    when Time, ActiveSupport::TimeWithZone then value.to_f
    when DateTime then value.to_time.to_f
    end
  end
end
