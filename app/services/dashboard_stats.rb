class DashboardStats
  FILTER_OPTIONS_CACHE_VERSION = "v1".freeze
  WEEKLY_PROJECT_DIMENSION = "weekly_project".freeze
  FILTERS = %i[project language operating_system editor category].freeze

  attr_reader :user, :params

  # `params` should respond to `[]`, `:blank?` and behave like
  # ActionController::Parameters. For non-controller callers (e.g.
  # ProfileStatsService) pass `ActionController::Parameters.new`.
  def initialize(user:, params: ActionController::Parameters.new)
    @user = user
    @params = params
  end

  # ---- Public surface ------------------------------------------------------

  def filterable_dashboard_data
    interval = params[:interval]
    key = [ user ] + FILTERS.map { |field| params[field] } + [ interval.to_s, params[:from], params[:to] ]

    if rollup_eligible?
      build_filterable_dashboard_data(interval)
    else
      Rails.cache.fetch(key, expires_in: 5.minutes) do
        build_filterable_dashboard_data(interval)
      end
    end
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
    archived = user.project_repo_mappings.archived.pluck(:project_name)
    raw_filter_options = raw_filter_options(archived: archived)
    result = rollup_result(raw_filter_options, archived)

    result ||= query_result(raw_filter_options, archived)
    result[:selected_interval] = interval.to_s
    result[:selected_from] = params[:from].to_s
    result[:selected_to] = params[:to].to_s
    FILTERS.each { |field| result["selected_#{field}"] = params[field]&.split(",") || [] }

    result
  end

  def raw_filter_options(archived: [])
    if rollup_eligible?
      rollup_options = rollup_filter_options
      return rollup_options if rollup_options
    end

    live_raw_filter_options
  end

  def live_raw_filter_options
    cache_keys = FILTERS.index_with do |field|
      "user_#{user.id}_dashboard_filter_options_#{field}_#{FILTER_OPTIONS_CACHE_VERSION}"
    end

    reverse_lookup = cache_keys.invert

    cached = Rails.cache.fetch_multi(*cache_keys.values, expires_in: 15.minutes) do |cache_key|
      user.heartbeats.distinct.pluck(reverse_lookup.fetch(cache_key)).compact_blank
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

    FILTERS.index_with do |field|
      Array(payload[field.to_s] || payload[field])
    end
  end

  def query_result(raw_filter_options, archived)
    hb = user.heartbeats
    result = filter_options_result(raw_filter_options, archived)
    h = ApplicationController.helpers

    Time.use_zone(user.timezone) do
      FILTERS.each do |field|
        next unless params[field].present?

        arr = params[field].split(",")
        hb = if field == :operating_system
          raw = raw_filter_options.fetch(:operating_system, []).select { |value| arr.include?(h.display_os_name(value)) }
          hb.where(field => raw)
        elsif field == :editor
          raw = raw_filter_options.fetch(:editor, []).select { |value| arr.include?(h.display_editor_name(value)) }
          hb.where(field => raw)
        elsif field == :language
          raw = raw_filter_options.fetch(:language, []).select { |language| arr.include?(language.categorize_language) }
          hb.where(field => raw)
        else
          hb.where(field => arr)
        end
        result["singular_#{field}"] = arr.length == 1
      end

      hb = hb.filter_by_time_range(params[:interval], params[:from], params[:to])
      fill_aggregate_result(
        result: result,
        grouped_durations: grouped_durations_snapshot(hb),
        total_time: hb.duration_seconds,
        total_heartbeats: hb.count,
        weekly_project_stats: weekly_project_stats(hb, user.timezone),
        archived: archived
      )
    end

    result
  end

  def rollup_result(raw_filter_options, archived)
    snapshot = aggregate_rollup_snapshot
    return unless snapshot

    result = filter_options_result(raw_filter_options, archived)

    Time.use_zone(user.timezone) do
      fill_aggregate_result(
        result: result,
        grouped_durations: snapshot.fetch(:grouped_durations),
        total_time: snapshot.fetch(:total_time),
        total_heartbeats: snapshot.fetch(:total_heartbeats),
        weekly_project_stats: snapshot.fetch(:weekly_project_stats),
        archived: archived
      )
    end

    result
  end

  def filter_options_result(raw_filter_options, archived)
    h = ApplicationController.helpers

    FILTERS.each_with_object({}) do |field, result|
      options = raw_filter_options.fetch(field, [])
      options = options.reject { |name| archived.include?(name) } if field == :project
      result[field] = options.map { |value|
        if field == :language then value.categorize_language
        elsif field == :editor then h.display_editor_name(value)
        elsif field == :operating_system then h.display_os_name(value)
        else value
        end
      }.uniq
    end
  end

  def fill_aggregate_result(result:, grouped_durations:, total_time:, total_heartbeats:, weekly_project_stats:, archived:)
    h = ApplicationController.helpers

    result[:total_time] = total_time
    result[:total_heartbeats] = total_heartbeats

    FILTERS.each do |field|
      stats = grouped_durations_for(grouped_durations, field, archived)
      result["top_#{field}"] = stats.max_by { |_, duration| duration }&.first
    end

    result["top_editor"] &&= h.display_editor_name(result["top_editor"])
    result["top_operating_system"] &&= h.display_os_name(result["top_operating_system"])
    result["top_language"] &&= h.display_language_name(result["top_language"])

    unless result["singular_project"]
      result[:project_durations] = grouped_durations_for(grouped_durations, :project, archived)
        .sort_by { |_, duration| -duration }.first(10).to_h
    end

    %i[language editor operating_system category].each do |field|
      next if result["singular_#{field}"]

      stats = grouped_durations.fetch(field, {}).each_with_object({}) do |(raw, duration), agg|
        next if raw.to_s.blank?

        key = if field == :language
          raw.to_s.categorize_language
        elsif %i[editor operating_system].include?(field)
          raw.to_s.downcase
        else
          raw.to_s
        end
        agg[key] = (agg[key] || 0) + duration
      end

      result["#{field}_stats"] = stats.sort_by { |_, duration| -duration }.first(10).map { |key, value|
        label = case field
        when :editor then h.display_editor_name(key)
        when :operating_system then h.display_os_name(key)
        when :language then h.display_language_name(key)
        else key
        end
        [ label, value ]
      }.to_h
    end

    if result["language_stats"].present?
      result[:language_colors] = LanguageUtils.colors_for(result["language_stats"].keys)
    end

    result[:weekly_project_stats] = weekly_project_stats.transform_values do |stats|
      stats.reject { |project, _| archived.include?(project) }
    end
  end

  def aggregate_rollup_snapshot
    return unless rollups_available?
    return unless rollup_eligible?

    total_row = rollup_total_row
    unless total_row
      schedule_rollup_refresh(wait: 0.seconds)
      return
    end

    schedule_rollup_refresh(wait: 0.seconds) if aggregate_rollup_stale?(total_row)

    {
      total_time: total_row.total_seconds,
      total_heartbeats: total_row.source_heartbeats_count.to_i,
      grouped_durations: FILTERS.index_with do |field|
        rollup_rows_by_dimension.fetch(field.to_s, []).to_h { |row| [ row.bucket, row.total_seconds ] }
      end,
      weekly_project_stats: rollup_weekly_project_stats(
        rollup_rows_by_dimension.fetch(WEEKLY_PROJECT_DIMENSION, [])
      )
    }
  end

  def rollup_eligible?
    params[:interval].blank? &&
      params[:from].blank? &&
      params[:to].blank? &&
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

  def rollup_rows_by_dimension
    @rollup_rows_by_dimension ||= rollup_rows.group_by(&:dimension)
  end

  def rollup_fragment_row(dimension)
    rollup_rows_by_dimension.fetch(dimension.to_s, []).first
  end

  def rollup_total_row
    @rollup_total_row ||= rollup_rows.find(&:total_dimension?)
  end

  def aggregate_rollup_stale?(total_row)
    DashboardRollup.dirty?(user.id) ||
      rollup_time_fingerprint(total_row.source_max_heartbeat_time) != rollup_source_max_heartbeat_time
  end

  def schedule_rollup_refresh(wait:)
    return if @rollup_refresh_scheduled

    DashboardRollupRefreshJob.schedule_for(user.id, wait: wait)
    @rollup_refresh_scheduled = true
  end

  def activity_graph_rollup_valid?(row)
    payload = row&.payload
    return false unless payload.is_a?(Hash)

    start_date, end_date = activity_graph_date_range(user.timezone)
    payload["timezone"] == user.timezone &&
      payload["start_date"] == start_date &&
      payload["end_date"] == end_date &&
      payload["duration_by_date"].is_a?(Hash)
  end

  def today_stats_rollup_valid?(row)
    payload = row&.payload
    return false unless payload.is_a?(Hash)

    payload["timezone"] == user.timezone &&
      payload["today_date"] == today_date &&
      payload.key?("todays_duration_seconds") &&
      payload["todays_language_categories"].is_a?(Array) &&
      payload["todays_editor_keys"].is_a?(Array)
  end

  def live_activity_graph_data
    timezone = user.timezone
    start_date, end_date = activity_graph_date_range(timezone)
    durations = Rails.cache.fetch(user.activity_graph_cache_key(timezone), expires_in: 1.minute) do
      Time.use_zone(timezone) { user.heartbeats.daily_durations(user_timezone: timezone).to_h }
    end

    activity_graph_result(
      start_date: start_date,
      end_date: end_date,
      duration_by_date: durations,
      timezone: timezone
    )
  end

  def activity_graph_from_rollup(row)
    payload = row.payload || {}

    activity_graph_result(
      start_date: payload["start_date"],
      end_date: payload["end_date"],
      duration_by_date: payload["duration_by_date"],
      timezone: payload["timezone"] || user.timezone
    )
  end

  def activity_graph_result(start_date:, end_date:, duration_by_date:, timezone:)
    DashboardData::Snapshots.activity_graph_result(
      start_date: start_date,
      end_date: end_date,
      duration_by_date: duration_by_date,
      timezone: timezone
    )
  end

  def live_today_stats_data
    snapshot = today_stats_snapshot(user.heartbeats)
    today_stats_result(
      todays_duration_seconds: snapshot[:todays_duration_seconds],
      todays_language_categories: snapshot[:todays_language_categories],
      todays_editor_keys: snapshot[:todays_editor_keys]
    )
  end

  def today_stats_from_rollup(row)
    payload = row.payload || {}

    today_stats_result(
      todays_duration_seconds: payload["todays_duration_seconds"],
      todays_language_categories: payload["todays_language_categories"],
      todays_editor_keys: payload["todays_editor_keys"]
    )
  end

  def today_stats_result(todays_duration_seconds:, todays_language_categories:, todays_editor_keys:)
    h = ApplicationController.helpers
    todays_languages = Array(todays_language_categories).filter_map do |language|
      h.display_language_name(language) if language.present?
    end
    todays_editors = Array(todays_editor_keys).filter_map do |editor|
      h.display_editor_name(editor) if editor.present?
    end
    todays_duration = todays_duration_seconds.to_i
    show_logged_time_sentence = todays_duration > 1.minute && (todays_languages.any? || todays_editors.any?)

    {
      show_logged_time_sentence: show_logged_time_sentence,
      todays_duration_display: h.short_time_detailed(todays_duration),
      todays_languages: todays_languages,
      todays_editors: todays_editors
    }
  end

  def today_stats_snapshot(scope)
    Time.use_zone(user.timezone) do
      rows = scope.today
        .select(:language, :editor,
                "COUNT(*) OVER (PARTITION BY language) as language_count",
                "COUNT(*) OVER (PARTITION BY editor) as editor_count")
        .distinct.to_a

      language_categories = rows
        .map { |row| [ row.language&.categorize_language, row.language_count ] }
        .reject { |language, _| language.blank? }
        .group_by(&:first)
        .transform_values { |pairs| pairs.sum(&:last) }
        .sort_by { |_, count| -count }
        .map(&:first)

      editor_keys = rows
        .map { |row| [ row.editor, row.editor_count ] }
        .reject { |editor, _| editor.blank? }
        .uniq
        .sort_by { |_, count| -count }
        .map(&:first)

      {
        today_date: Date.current.iso8601,
        todays_duration_seconds: scope.today.duration_seconds.to_i,
        todays_language_categories: language_categories,
        todays_editor_keys: editor_keys
      }
    end
  end

  def today_date
    Time.use_zone(user.timezone) { Date.current.iso8601 }
  end

  def activity_graph_date_range(timezone)
    Time.use_zone(timezone) do
      [ 365.days.ago.to_date.iso8601, Date.current.iso8601 ]
    end
  end

  def rollup_source_max_heartbeat_time
    rollup_time_fingerprint(user.heartbeats.maximum(:time))
  end

  def rollup_weekly_project_stats(rows)
    result = week_ranges.to_h { |week_key, *_| [ week_key, {} ] }

    rows.each do |row|
      week_key, project = JSON.parse(row.bucket_value)
      next unless result.key?(week_key)

      result[week_key][project] = row.total_seconds
    end

    result
  end

  def rollup_time_fingerprint(timestamp)
    return if timestamp.nil?

    (timestamp * 1_000_000).round
  end

  def grouped_durations_snapshot(scope)
    FILTERS.index_with do |field|
      field == :project ? project_grouped_durations(scope) : Heartbeat.attributed_durations_by(scope, field)
    end
  end

  def grouped_durations_for(grouped_durations, field, archived)
    stats = grouped_durations.fetch(field, {})
    return stats unless field == :project

    stats.reject { |project, _| archived.include?(project) }
  end

  def project_grouped_durations(scope)
    non_null = scope.where.not(project: nil).group(:project).duration_seconds
    return non_null if scope.where(project: nil).none?

    null_duration = scope.where(project: nil).duration_seconds
    return non_null if null_duration.zero?

    non_null.merge(nil => null_duration)
  end

  def weekly_project_stats(scope, timezone)
    week_ranges_value = week_ranges
    result = week_ranges_value.to_h { |week_key, *_| [ week_key, {} ] }

    relation_sql = scope.with_valid_timestamps
      .where.not(time: nil)
      .where(time: week_ranges_value.last[1]..week_ranges_value.first[2])
      .select(:id, :time, :project)
      .to_sql

    quoted_timezone = Heartbeat.connection.quote(timezone)
    week_group_sql = "DATE_TRUNC('week', to_timestamp(time) AT TIME ZONE #{quoted_timezone})"

    rows = Heartbeat.connection.select_all(<<~SQL.squish)
      SELECT TO_CHAR(week_group, 'YYYY-MM-DD') AS week_key,
             grouped_time,
             COALESCE(SUM(diff), 0)::integer AS duration
      FROM (
        SELECT project AS grouped_time,
               #{week_group_sql} AS week_group,
               CASE
                 WHEN LAG(time) OVER (PARTITION BY project, #{week_group_sql} ORDER BY time, id) IS NULL THEN 0
                 ELSE LEAST(
                   time - LAG(time) OVER (PARTITION BY project, #{week_group_sql} ORDER BY time, id),
                   #{Heartbeat.heartbeat_timeout_duration.to_i}
                 )
               END AS diff
        FROM (#{relation_sql}) dashboard_heartbeats
      ) diffs
      GROUP BY week_group, grouped_time
      ORDER BY week_key DESC, grouped_time
    SQL

    rows.each do |row|
      result[row["week_key"]][row["grouped_time"]] = row["duration"].to_i
    end

    result
  end

  def week_ranges
    Time.use_zone(user.timezone) do
      (0..11).map do |week_offset|
        week_start = week_offset.weeks.ago.beginning_of_week
        [ week_start.to_date.iso8601, week_start.to_f, week_offset.weeks.ago.end_of_week.to_f ]
      end
    end
  end
end
