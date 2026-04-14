module DashboardData
  extend ActiveSupport::Concern

  FILTER_OPTIONS_CACHE_VERSION = "v1".freeze

  private

  def filterable_dashboard_data
    filters = dashboard_filters
    interval = params[:interval]
    key = [ current_user ] + filters.map { |f| params[f] } + [ interval.to_s, params[:from], params[:to] ]

    Rails.cache.fetch(key, expires_in: 5.minutes) do
      archived = current_user.project_repo_mappings.archived.pluck(:project_name)
      raw_filter_options = dashboard_raw_filter_options
      result = dashboard_rollup_result(raw_filter_options, archived)

      result ||= dashboard_query_result(raw_filter_options, archived)
      result[:selected_interval] = interval.to_s
      result[:selected_from] = params[:from].to_s
      result[:selected_to] = params[:to].to_s
      filters.each { |f| result["selected_#{f}"] = params[f]&.split(",") || [] }

      result
    end
  end

  def activity_graph_data
    tz = current_user.timezone
    key = "user_#{current_user.id}_daily_durations_#{tz}"
    durations = Rails.cache.fetch(key, expires_in: 1.minute) do
      Time.use_zone(tz) { current_user.heartbeats.daily_durations(user_timezone: tz).to_h }
    end

    {
      start_date: 365.days.ago.to_date.iso8601,
      end_date: Time.current.to_date.iso8601,
      duration_by_date: durations.transform_keys { |d| d.to_date.iso8601 }.transform_values(&:to_i),
      busiest_day_seconds: 8.hours.to_i,
      timezone_label: ActiveSupport::TimeZone[tz].to_s,
      timezone_settings_path: "/my/settings#user_timezone"
    }
  end

  def today_stats_data
    h = ApplicationController.helpers
    Time.use_zone(current_user.timezone) do
      rows = current_user.heartbeats.today
        .select(:language, :editor,
                "COUNT(*) OVER (PARTITION BY language) as language_count",
                "COUNT(*) OVER (PARTITION BY editor) as editor_count")
        .distinct.to_a

      lang_counts = rows
        .map { |r| [ r.language&.categorize_language, r.language_count ] }
        .reject { |l, _| l.blank? }
        .group_by(&:first).transform_values { |p| p.sum(&:last) }
        .sort_by { |_, c| -c }

      ed_counts = rows
        .map { |r| [ r.editor, r.editor_count ] }
        .reject { |e, _| e.blank? }.uniq
        .sort_by { |_, c| -c }

      todays_languages = lang_counts.map { |l, _| h.display_language_name(l) }
      todays_editors = ed_counts.map { |e, _| h.display_editor_name(e) }
      todays_duration = current_user.heartbeats.today.duration_seconds
      show_logged_time_sentence = todays_duration > 1.minute && (todays_languages.any? || todays_editors.any?)

      {
        show_logged_time_sentence: show_logged_time_sentence,
        todays_duration_display: h.short_time_detailed(todays_duration.to_i),
        todays_languages: todays_languages,
        todays_editors: todays_editors
      }
    end
  end

  def dashboard_filters
    %i[project language operating_system editor category]
  end

  def dashboard_raw_filter_options
    cache_keys = dashboard_filters.index_with do |field|
      "user_#{current_user.id}_dashboard_filter_options_#{field}_#{FILTER_OPTIONS_CACHE_VERSION}"
    end

    reverse_lookup = cache_keys.invert

    cached = Rails.cache.fetch_multi(*cache_keys.values, expires_in: 15.minutes) do |cache_key|
      current_user.heartbeats.distinct.pluck(reverse_lookup.fetch(cache_key)).compact_blank
    end

    cache_keys.transform_values { |cache_key| cached.fetch(cache_key, []) }
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
    snapshot = dashboard_rollup_snapshot
    return unless snapshot

    result = dashboard_filter_options_result(raw_filter_options, archived)

    Time.use_zone(current_user.timezone) do
      dashboard_fill_aggregate_result(
        result: result,
        grouped_durations: snapshot.fetch(:grouped_durations),
        total_time: snapshot.fetch(:total_time),
        total_heartbeats: snapshot.fetch(:total_heartbeats),
        weekly_project_stats: dashboard_weekly_project_stats(current_user.heartbeats, current_user.timezone),
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

  def dashboard_rollup_snapshot
    return unless dashboard_rollups_available?
    return unless dashboard_rollup_eligible?
    if DashboardRollup.dirty?(current_user.id)
      DashboardRollupRefreshJob.schedule_for(current_user.id, wait: 0.seconds)
      return
    end

    rows = DashboardRollup.where(user_id: current_user.id).to_a
    total_row = rows.find(&:total_dimension?)
    unless total_row
      DashboardRollupRefreshJob.schedule_for(current_user.id, wait: 0.seconds)
      return
    end

    source_heartbeats_count, source_max_heartbeat_time = dashboard_rollup_source_fingerprint
    if total_row.source_heartbeats_count.to_i != source_heartbeats_count ||
        total_row.source_max_heartbeat_time.to_f != source_max_heartbeat_time.to_f
      DashboardRollupRefreshJob.schedule_for(current_user.id, wait: 0.seconds)
      return
    end

    grouped_rows = rows.reject(&:total_dimension?).group_by(&:dimension)

    {
      total_time: total_row.total_seconds,
      total_heartbeats: total_row.source_heartbeats_count.to_i,
      grouped_durations: dashboard_filters.index_with do |field|
        grouped_rows.fetch(field.to_s, []).to_h { |row| [ row.bucket, row.total_seconds ] }
      end
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

  def dashboard_rollup_source_fingerprint
    row = current_user.heartbeats.pluck(Arel.sql("COUNT(*)"), Arel.sql("MAX(time)")).first
    [ row[0].to_i, row[1]&.to_f ]
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
    (0..11).map do |w|
      week_start = w.weeks.ago.beginning_of_week
      [ week_start.to_date.iso8601, week_start.to_f, w.weeks.ago.end_of_week.to_f ]
    end
  end
end
