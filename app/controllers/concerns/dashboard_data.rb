module DashboardData
  extend ActiveSupport::Concern

  FILTER_OPTIONS_CACHE_VERSION = "v1".freeze
  WEEKLY_PROJECT_DIMENSION = "weekly_project".freeze
  DASHBOARD_TIMEZONE_SETTINGS_PATH = "/my/settings#user_timezone".freeze

  private

  def filterable_dashboard_data
    filters = dashboard_filters
    interval = params[:interval]
    key = [ current_user ] + filters.map { |field| params[field] } + [ interval.to_s, params[:from], params[:to] ]

    if dashboard_rollup_eligible?
      build_filterable_dashboard_data(filters, interval)
    else
      Rails.cache.fetch(key, expires_in: 5.minutes) do
        build_filterable_dashboard_data(filters, interval)
      end
    end
  end

  def activity_graph_data
    row = dashboard_rollup_fragment_row(DashboardRollup::ACTIVITY_GRAPH_DIMENSION)
    return dashboard_activity_graph_from_rollup(row) if dashboard_activity_graph_rollup_valid?(row)

    dashboard_schedule_rollup_refresh(wait: 0.seconds) if dashboard_rollups_available?
    dashboard_live_activity_graph_data
  end

  def today_stats_data
    row = dashboard_rollup_fragment_row(DashboardRollup::TODAY_STATS_DIMENSION)
    return dashboard_today_stats_from_rollup(row) if dashboard_today_stats_rollup_valid?(row)

    dashboard_schedule_rollup_refresh(wait: 0.seconds) if dashboard_rollups_available?
    dashboard_live_today_stats_data
  end

  def dashboard_filters
    %i[project language operating_system editor category]
  end

  def build_filterable_dashboard_data(filters, interval)
    archived = current_user.project_repo_mappings.archived.pluck(:project_name)
    raw_filter_options = dashboard_raw_filter_options
    result = dashboard_rollup_result(raw_filter_options, archived)

    result ||= dashboard_query_result(raw_filter_options, archived)
    result[:selected_interval] = interval.to_s
    result[:selected_from] = params[:from].to_s
    result[:selected_to] = params[:to].to_s
    filters.each { |field| result["selected_#{field}"] = params[field]&.split(",") || [] }

    result
  end

  def dashboard_raw_filter_options
    if dashboard_rollup_eligible?
      rollup_options = dashboard_rollup_filter_options
      return rollup_options if rollup_options
    end

    dashboard_live_raw_filter_options
  end

  def dashboard_live_raw_filter_options
    cache_keys = dashboard_filters.index_with do |field|
      "user_#{current_user.id}_dashboard_filter_options_#{field}_#{FILTER_OPTIONS_CACHE_VERSION}"
    end

    reverse_lookup = cache_keys.invert

    cached = Rails.cache.fetch_multi(*cache_keys.values, expires_in: 15.minutes) do |cache_key|
      current_user.heartbeats.distinct.pluck(reverse_lookup.fetch(cache_key)).compact_blank
    end

    cache_keys.transform_values { |cache_key| cached.fetch(cache_key, []) }
  end

  def dashboard_rollup_filter_options
    return unless dashboard_rollups_available?

    row = dashboard_rollup_fragment_row(DashboardRollup::FILTER_OPTIONS_DIMENSION)
    payload = row&.payload
    unless payload.is_a?(Hash) && dashboard_filters.all? { |field| payload[field.to_s].is_a?(Array) || payload[field].is_a?(Array) }
      dashboard_schedule_rollup_refresh(wait: 0.seconds)
      return
    end

    dashboard_filters.index_with do |field|
      Array(payload[field.to_s] || payload[field])
    end
  end

  def dashboard_query_result(raw_filter_options, archived)
    hb = current_user.heartbeats
    result = dashboard_filter_options_result(raw_filter_options, archived)

    Time.use_zone(current_user.timezone) do
      dashboard_filters.each do |field|
        next unless params[field].present?

        arr = params[field].split(",")
        hb = if %i[operating_system editor].include?(field)
          hb.where(field => arr.flat_map { |value| [ value.downcase, value.capitalize ] }.uniq)
        elsif field == :language
          raw = raw_filter_options.fetch(:language, []).select { |language| arr.include?(language.categorize_language) }
          raw.any? ? hb.where(field => raw) : hb
        else
          hb.where(field => arr)
        end
        result["singular_#{field}"] = arr.length == 1
      end

      hb = hb.filter_by_time_range(params[:interval], params[:from], params[:to])
      dashboard_fill_aggregate_result(
        result: result,
        grouped_durations: dashboard_grouped_durations_snapshot(hb),
        total_time: hb.duration_seconds,
        total_heartbeats: hb.count,
        weekly_project_stats: dashboard_weekly_project_stats(hb, current_user.timezone),
        archived: archived
      )
    end

    result
  end

  def dashboard_rollup_result(raw_filter_options, archived)
    snapshot = dashboard_aggregate_rollup_snapshot
    return unless snapshot

    result = dashboard_filter_options_result(raw_filter_options, archived)

    Time.use_zone(current_user.timezone) do
      dashboard_fill_aggregate_result(
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

  def dashboard_filter_options_result(raw_filter_options, archived)
    h = ApplicationController.helpers

    dashboard_filters.each_with_object({}) do |field, result|
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

  def dashboard_fill_aggregate_result(result:, grouped_durations:, total_time:, total_heartbeats:, weekly_project_stats:, archived:)
    h = ApplicationController.helpers

    result[:total_time] = total_time
    result[:total_heartbeats] = total_heartbeats

    dashboard_filters.each do |field|
      stats = dashboard_grouped_durations(grouped_durations, field, archived)
      result["top_#{field}"] = stats.max_by { |_, duration| duration }&.first
    end

    result["top_editor"] &&= h.display_editor_name(result["top_editor"])
    result["top_operating_system"] &&= h.display_os_name(result["top_operating_system"])
    result["top_language"] &&= h.display_language_name(result["top_language"])

    unless result["singular_project"]
      result[:project_durations] = dashboard_grouped_durations(grouped_durations, :project, archived)
        .sort_by { |_, duration| -duration }.first(10).to_h
    end

    %i[language editor operating_system category].each do |field|
      next if result["singular_#{field}"]

      stats = grouped_durations.fetch(field, {}).each_with_object({}) do |(raw, duration), agg|
        key = raw.to_s.presence || "Unknown"
        key = if field == :language
          key == "Unknown" ? key : key.categorize_language
        elsif %i[editor operating_system].include?(field)
          key.downcase
        else
          key
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

  def dashboard_aggregate_rollup_snapshot
    return unless dashboard_rollups_available?
    return unless dashboard_rollup_eligible?

    total_row = dashboard_rollup_total_row
    unless total_row
      dashboard_schedule_rollup_refresh(wait: 0.seconds)
      return
    end

    dashboard_schedule_rollup_refresh(wait: 0.seconds) if dashboard_aggregate_rollup_stale?(total_row)

    {
      total_time: total_row.total_seconds,
      total_heartbeats: total_row.source_heartbeats_count.to_i,
      grouped_durations: dashboard_filters.index_with do |field|
        dashboard_rollup_rows_by_dimension.fetch(field.to_s, []).to_h { |row| [ row.bucket, row.total_seconds ] }
      end,
      weekly_project_stats: dashboard_rollup_weekly_project_stats(
        dashboard_rollup_rows_by_dimension.fetch(WEEKLY_PROJECT_DIMENSION, [])
      )
    }
  end

  def dashboard_rollup_eligible?
    params[:interval].blank? &&
      params[:from].blank? &&
      params[:to].blank? &&
      dashboard_filters.none? { |field| params[field].present? }
  end

  def dashboard_rollups_available?
    DashboardRollup.table_exists?
  rescue ActiveRecord::StatementInvalid
    false
  end

  def dashboard_rollup_rows
    return [] unless dashboard_rollups_available?

    @dashboard_rollup_rows ||= DashboardRollup.where(user_id: current_user.id).to_a
  end

  def dashboard_rollup_rows_by_dimension
    @dashboard_rollup_rows_by_dimension ||= dashboard_rollup_rows.group_by(&:dimension)
  end

  def dashboard_rollup_fragment_row(dimension)
    dashboard_rollup_rows_by_dimension.fetch(dimension.to_s, []).first
  end

  def dashboard_rollup_total_row
    @dashboard_rollup_total_row ||= dashboard_rollup_rows.find(&:total_dimension?)
  end

  def dashboard_aggregate_rollup_stale?(total_row)
    DashboardRollup.dirty?(current_user.id) ||
      dashboard_rollup_time_fingerprint(total_row.source_max_heartbeat_time) != dashboard_rollup_source_max_heartbeat_time
  end

  def dashboard_schedule_rollup_refresh(wait:)
    return if @dashboard_rollup_refresh_scheduled

    DashboardRollupRefreshJob.schedule_for(current_user.id, wait: wait)
    @dashboard_rollup_refresh_scheduled = true
  end

  def dashboard_activity_graph_rollup_valid?(row)
    payload = row&.payload
    return false unless payload.is_a?(Hash)

    start_date, end_date = dashboard_activity_graph_date_range(current_user.timezone)
    payload["timezone"] == current_user.timezone &&
      payload["start_date"] == start_date &&
      payload["end_date"] == end_date &&
      payload["duration_by_date"].is_a?(Hash)
  end

  def dashboard_today_stats_rollup_valid?(row)
    payload = row&.payload
    return false unless payload.is_a?(Hash)

    payload["timezone"] == current_user.timezone &&
      payload["today_date"] == dashboard_today_date &&
      payload.key?("todays_duration_seconds") &&
      payload["todays_language_categories"].is_a?(Array) &&
      payload["todays_editor_keys"].is_a?(Array)
  end

  def dashboard_live_activity_graph_data
    timezone = current_user.timezone
    start_date, end_date = dashboard_activity_graph_date_range(timezone)
    durations = Rails.cache.fetch(current_user.activity_graph_cache_key(timezone), expires_in: 1.minute) do
      Time.use_zone(timezone) { current_user.heartbeats.daily_durations(user_timezone: timezone).to_h }
    end

    dashboard_activity_graph_result(
      start_date: start_date,
      end_date: end_date,
      duration_by_date: durations,
      timezone: timezone
    )
  end

  def dashboard_activity_graph_from_rollup(row)
    payload = row.payload || {}

    dashboard_activity_graph_result(
      start_date: payload["start_date"],
      end_date: payload["end_date"],
      duration_by_date: payload["duration_by_date"],
      timezone: payload["timezone"] || current_user.timezone
    )
  end

  def dashboard_activity_graph_result(start_date:, end_date:, duration_by_date:, timezone:)
    {
      start_date: start_date,
      end_date: end_date,
      duration_by_date: duration_by_date.to_h.transform_keys { |date| date.to_s }.transform_values(&:to_i),
      busiest_day_seconds: 8.hours.to_i,
      timezone_label: ActiveSupport::TimeZone[timezone]&.to_s || timezone,
      timezone_settings_path: DASHBOARD_TIMEZONE_SETTINGS_PATH
    }
  end

  def dashboard_live_today_stats_data
    snapshot = dashboard_today_stats_snapshot(current_user.heartbeats)
    dashboard_today_stats_result(
      todays_duration_seconds: snapshot[:todays_duration_seconds],
      todays_language_categories: snapshot[:todays_language_categories],
      todays_editor_keys: snapshot[:todays_editor_keys]
    )
  end

  def dashboard_today_stats_from_rollup(row)
    payload = row.payload || {}

    dashboard_today_stats_result(
      todays_duration_seconds: payload["todays_duration_seconds"],
      todays_language_categories: payload["todays_language_categories"],
      todays_editor_keys: payload["todays_editor_keys"]
    )
  end

  def dashboard_today_stats_result(todays_duration_seconds:, todays_language_categories:, todays_editor_keys:)
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

  def dashboard_today_stats_snapshot(scope)
    Time.use_zone(current_user.timezone) do
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

  def dashboard_today_date
    Time.use_zone(current_user.timezone) { Date.current.iso8601 }
  end

  def dashboard_activity_graph_date_range(timezone)
    Time.use_zone(timezone) do
      [ 365.days.ago.to_date.iso8601, Date.current.iso8601 ]
    end
  end

  def dashboard_rollup_source_max_heartbeat_time
    dashboard_rollup_time_fingerprint(current_user.heartbeats.maximum(:time))
  end

  def dashboard_rollup_weekly_project_stats(rows)
    result = dashboard_week_ranges.to_h { |week_key, *_| [ week_key, {} ] }

    rows.each do |row|
      week_key, project = JSON.parse(row.bucket_value)
      next unless result.key?(week_key)

      result[week_key][project] = row.total_seconds
    end

    result
  end

  def dashboard_rollup_time_fingerprint(timestamp)
    return if timestamp.nil?

    (timestamp * 1_000_000).round
  end

  def dashboard_grouped_durations_snapshot(scope)
    dashboard_filters.index_with do |field|
      field == :project ? dashboard_project_grouped_durations(scope) : scope.group(field).duration_seconds
    end
  end

  def dashboard_grouped_durations(grouped_durations, field, archived)
    stats = grouped_durations.fetch(field, {})
    return stats unless field == :project

    stats.reject { |project, _| archived.include?(project) }
  end

  def dashboard_project_grouped_durations(scope)
    non_null = scope.where.not(project: nil).group(:project).duration_seconds
    return non_null if scope.where(project: nil).none?

    null_duration = scope.where(project: nil).duration_seconds
    return non_null if null_duration.zero?

    non_null.merge(nil => null_duration)
  end

  def dashboard_weekly_project_stats(scope, timezone)
    week_ranges = dashboard_week_ranges
    result = week_ranges.to_h { |week_key, *_| [ week_key, {} ] }

    relation_sql = scope.with_valid_timestamps
      .where.not(time: nil)
      .where(time: week_ranges.last[1]..week_ranges.first[2])
      .select(:time, :project)
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
                 WHEN LAG(time) OVER (PARTITION BY project, #{week_group_sql} ORDER BY time) IS NULL THEN 0
                 ELSE LEAST(
                   time - LAG(time) OVER (PARTITION BY project, #{week_group_sql} ORDER BY time),
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

  def dashboard_week_ranges
    Time.use_zone(current_user.timezone) do
      (0..11).map do |week_offset|
        week_start = week_offset.weeks.ago.beginning_of_week
        [ week_start.to_date.iso8601, week_start.to_f, week_offset.weeks.ago.end_of_week.to_f ]
      end
    end
  end
end
