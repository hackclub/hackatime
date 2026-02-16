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
    names = normalize_names(names)
    names = project_names if names.empty?
    return [] if names.empty?

    query = scoped_heartbeats(stats_start_time, stats_end_time)
            .where(project: names)
    return [] unless query.exists?

    stats = query.group(:project)
                 .select("project, COUNT(*) AS heartbeat_count, MIN(time) AS first_heartbeat, MAX(time) AS last_heartbeat")
                 .index_by(&:project)

    durations = query.group(:project).duration_seconds

    languages_by_project = query.where.not(language: [ nil, "" ])
                                .group(:project, :language)
                                .pluck(:project, :language)
                                .group_by(&:first)
                                .transform_values { |pairs| pairs.map(&:last).uniq }

    repo_mappings = @user.project_repo_mappings
                         .where(project_name: names)
                         .index_by(&:project_name)

    names.filter_map do |name|
      stat = stats[name]
      next unless stat

      repo_mapping = repo_mappings[name]
      archived = repo_mapping&.archived? || false
      next if archived && !@include_archived

      first_heartbeat = format_heartbeat_time(stat.first_heartbeat)
      last_heartbeat = format_heartbeat_time(stat.last_heartbeat)

      {
        name: name,
        total_seconds: durations[name] || 0,
        languages: languages_by_project[name] || [],
        repo_url: repo_mapping&.repo_url,
        total_heartbeats: stat.heartbeat_count || 0,
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
    @user.heartbeats
         .with_valid_timestamps
         .where.not(project: [ nil, "" ])
         .where(time: start_time..end_time)
  end

  def archived_project_names
    @archived_project_names ||= @user.project_repo_mappings.archived.pluck(:project_name)
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

    return value.in_time_zone if value.respond_to?(:in_time_zone)

    Time.zone.parse(value.to_s)
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
end
