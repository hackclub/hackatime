class DashboardSnapshot < ApplicationService
  FILTERS = %i[project language operating_system editor category].freeze
  FILTER_OPTIONS_CACHE_VERSION = "v1".freeze
  GROUPED_DIMENSIONS = FILTERS.freeze
  WEEKLY_PROJECT_DIMENSION = "weekly_project".freeze

  Result = Data.define(:filterable_dashboard_data, :activity_graph, :today_stats, :sources)
  Raw = Data.define(
    :total_time,
    :total_heartbeats,
    :source_max_heartbeat_time,
    :grouped_durations,
    :filter_options,
    :weekly_project_stats,
    :activity_graph,
    :today_stats,
    :timezone
  )

  def initialize(user:, params: {}, rollup_rows: nil)
    @user = user
    @params = params.respond_to?(:to_unsafe_h) ? params : ActionController::Parameters.new(params)
    @rollup_rows = rollup_rows
    @sources = {}
    @rollup_refresh_scheduled = false
  end

  def call
    raw_filter_options = raw_filter_options_for_read
    archived = @user.project_repo_mappings.archived.pluck(:project_name)
    aggregate_raw = aggregate_raw_for_read(raw_filter_options)

    Result.new(
      filterable_dashboard_data: build_filterable_dashboard_data(aggregate_raw, archived),
      activity_graph: build_activity_graph(activity_graph_raw_for_read),
      today_stats: build_today_stats(today_stats_raw_for_read),
      sources: @sources.dup
    )
  end

  def persist_rollups!
    now = Time.current
    raw = live_raw_snapshot(filter_options: live_raw_filter_options).with(
      activity_graph: live_activity_graph_raw,
      today_stats: live_today_stats_raw(@user.heartbeats)
    )
    records = rollup_records(raw, now: now)

    DashboardRollup.transaction do
      DashboardRollup.where(user_id: @user.id).delete_all
      DashboardRollup.insert_all!(records)
    end

    DashboardRollup.clear_dirty(@user.id)
  end

  private

  def build_filterable_dashboard_data(raw, archived)
    result = filter_options_result(raw.filter_options, archived)
    filter_selections = selected_filters

    result[:total_time] = raw.total_time
    result[:total_heartbeats] = raw.total_heartbeats
    result[:selected_interval] = @params[:interval].to_s
    result[:selected_from] = @params[:from].to_s
    result[:selected_to] = @params[:to].to_s

    FILTERS.each do |field|
      arr = filter_selections.fetch(field)
      result["selected_#{field}"] = arr
      result["singular_#{field}"] = arr.length == 1 if arr.any?
      result["top_#{field}"] = grouped_durations(raw.grouped_durations, field, archived).max_by { |_, duration| duration }&.first
    end

    h = ApplicationController.helpers
    result["top_editor"] &&= h.display_editor_name(result["top_editor"])
    result["top_operating_system"] &&= h.display_os_name(result["top_operating_system"])
    result["top_language"] &&= h.display_language_name(result["top_language"])

    unless result["singular_project"]
      result[:project_durations] = grouped_durations(raw.grouped_durations, :project, archived)
        .sort_by { |_, duration| -duration }.first(10).to_h
    end

    %i[language editor operating_system category].each do |field|
      next if result["singular_#{field}"]

      stats = raw.grouped_durations.fetch(field, {}).each_with_object({}) do |(raw_key, duration), agg|
        key = raw_key.to_s.presence || "Unknown"
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

    result[:language_colors] = LanguageUtils.colors_for(result["language_stats"].keys) if result["language_stats"].present?
    result[:weekly_project_stats] = raw.weekly_project_stats.transform_values { |stats| stats.reject { |project, _| archived.include?(project) } }
    result
  end

  def build_activity_graph(raw)
    {
      start_date: raw.fetch(:start_date),
      end_date: raw.fetch(:end_date),
      duration_by_date: raw.fetch(:duration_by_date).to_h.transform_keys { |date| date.to_s }.transform_values(&:to_i),
      busiest_day_seconds: 8.hours.to_i,
      timezone_label: ActiveSupport::TimeZone[raw.fetch(:timezone)]&.to_s || raw.fetch(:timezone)
    }
  end

  def build_today_stats(raw)
    h = ApplicationController.helpers
    todays_languages = Array(raw.fetch(:todays_language_categories)).filter_map { |language| h.display_language_name(language) if language.present? }
    todays_editors = Array(raw.fetch(:todays_editor_keys)).filter_map { |editor| h.display_editor_name(editor) if editor.present? }
    todays_duration = raw.fetch(:todays_duration_seconds).to_i

    {
      show_logged_time_sentence: todays_duration > 1.minute && (todays_languages.any? || todays_editors.any?),
      todays_duration_display: h.short_time_detailed(todays_duration),
      todays_languages: todays_languages,
      todays_editors: todays_editors
    }
  end

  def aggregate_raw_for_read(raw_filter_options)
    if rollup_eligible?
      raw = aggregate_rollup_raw(raw_filter_options)
      return raw if raw
    end

    @sources[:aggregate] = :live
    scope = filtered_scope(raw_filter_options)
    if rollup_eligible?
      live_raw_snapshot(filter_options: raw_filter_options, scope: scope)
    else
      cached = Rails.cache.fetch(live_aggregate_cache_key, expires_in: 5.minutes) do
        live_raw_snapshot(filter_options: raw_filter_options, scope: scope).to_h
      end
      cached.is_a?(Raw) ? cached : Raw.new(**cached.symbolize_keys)
    end
  end

  def raw_filter_options_for_read
    if rollup_eligible?
      options = rollup_filter_options
      return options if options
    end

    @sources[:filter_options] = :live
    live_raw_filter_options
  end

  def aggregate_rollup_raw(filter_options)
    return unless rollups_available?
    return unless rollup_eligible?

    total_row = rollup_total_row
    unless total_row
      schedule_rollup_refresh(wait: 0.seconds)
      return
    end

    if aggregate_rollup_stale?(total_row)
      schedule_rollup_refresh(wait: 0.seconds)
      @sources[:aggregate] = :stale_rollup
    else
      @sources[:aggregate] = :rollup
    end

    Raw.new(
      total_time: total_row.total_seconds,
      total_heartbeats: total_row.source_heartbeats_count.to_i,
      source_max_heartbeat_time: total_row.source_max_heartbeat_time,
      grouped_durations: FILTERS.index_with { |field| rollup_rows_by_dimension.fetch(field.to_s, []).to_h { |row| [ row.bucket, row.total_seconds ] } },
      filter_options: filter_options,
      weekly_project_stats: rollup_weekly_project_stats(rollup_rows_by_dimension.fetch(WEEKLY_PROJECT_DIMENSION, [])),
      activity_graph: nil,
      today_stats: nil,
      timezone: @user.timezone
    )
  end

  def activity_graph_raw_for_read
    row = rollup_fragment_row(DashboardRollup::ACTIVITY_GRAPH_DIMENSION)
    if activity_graph_rollup_valid?(row)
      @sources[:activity_graph] = :rollup
      return activity_graph_from_rollup(row)
    end

    schedule_rollup_refresh(wait: 0.seconds) if rollups_available?
    @sources[:activity_graph] = :live
    live_activity_graph_raw
  end

  def today_stats_raw_for_read
    row = rollup_fragment_row(DashboardRollup::TODAY_STATS_DIMENSION)
    if today_stats_rollup_valid?(row)
      @sources[:today_stats] = :rollup
      return today_stats_from_rollup(row)
    end

    schedule_rollup_refresh(wait: 0.seconds) if rollups_available?
    @sources[:today_stats] = :live
    live_today_stats_raw(@user.heartbeats)
  end

  def live_raw_snapshot(filter_options:, scope: @user.heartbeats)
    Time.use_zone(@user.timezone) do
      Raw.new(
        total_time: scope.duration_seconds,
        total_heartbeats: scope.count,
        source_max_heartbeat_time: scope.maximum(:time),
        grouped_durations: grouped_durations_snapshot(scope),
        filter_options: filter_options,
        weekly_project_stats: weekly_project_stats(scope, @user.timezone),
        activity_graph: nil,
        today_stats: nil,
        timezone: @user.timezone
      )
    end
  end

  def live_raw_filter_options
    cache_keys = FILTERS.index_with { |field| "user_#{@user.id}_dashboard_filter_options_#{field}_#{FILTER_OPTIONS_CACHE_VERSION}" }
    reverse_lookup = cache_keys.invert

    cached = Rails.cache.fetch_multi(*cache_keys.values, expires_in: 15.minutes) do |cache_key|
      @user.heartbeats.distinct.pluck(reverse_lookup.fetch(cache_key)).compact_blank
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

    @sources[:filter_options] = :rollup
    FILTERS.index_with { |field| Array(payload[field.to_s] || payload[field]) }
  end

  def filtered_scope(raw_filter_options)
    hb = @user.heartbeats
    selected_filters.each do |field, arr|
      next if arr.blank?

      hb = if %i[operating_system editor].include?(field)
        hb.where(field => arr.flat_map { |value| [ value.downcase, value.capitalize ] }.uniq)
      elsif field == :language
        raw = raw_filter_options.fetch(:language, []).select { |language| arr.include?(language.categorize_language) }
        raw.any? ? hb.where(field => raw) : hb
      else
        hb.where(field => arr)
      end
    end

    hb.filter_by_time_range(@params[:interval], @params[:from], @params[:to])
  end

  def selected_filters
    FILTERS.index_with { |field| @params[field]&.split(",") || [] }
  end

  def live_aggregate_cache_key
    [ @user ] + FILTERS.map { |field| @params[field] } + [ @params[:interval].to_s, @params[:from], @params[:to] ]
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

  def live_activity_graph_raw
    timezone = @user.timezone
    start_date, end_date = activity_graph_date_range(timezone)
    durations = Rails.cache.fetch(@user.activity_graph_cache_key(timezone), expires_in: 1.minute) do
      Time.use_zone(timezone) { @user.heartbeats.daily_durations(user_timezone: timezone).to_h }
    end

    { timezone: timezone, start_date: start_date, end_date: end_date, duration_by_date: durations }
  end

  def activity_graph_from_rollup(row)
    payload = row.payload || {}
    {
      timezone: payload["timezone"] || @user.timezone,
      start_date: payload["start_date"],
      end_date: payload["end_date"],
      duration_by_date: payload["duration_by_date"]
    }
  end

  def live_today_stats_raw(scope)
    Time.use_zone(@user.timezone) do
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
        timezone: @user.timezone,
        today_date: Date.current.iso8601,
        todays_duration_seconds: scope.today.duration_seconds.to_i,
        todays_language_categories: language_categories,
        todays_editor_keys: editor_keys
      }
    end
  end

  def today_stats_from_rollup(row)
    payload = row.payload || {}
    {
      timezone: payload["timezone"] || @user.timezone,
      today_date: payload["today_date"],
      todays_duration_seconds: payload["todays_duration_seconds"],
      todays_language_categories: payload["todays_language_categories"],
      todays_editor_keys: payload["todays_editor_keys"]
    }
  end

  def grouped_durations_snapshot(scope)
    FILTERS.index_with { |field| field == :project ? project_grouped_durations(scope) : scope.group(field).duration_seconds }
  end

  def project_grouped_durations(scope)
    non_null = scope.where.not(project: nil).group(:project).duration_seconds
    return non_null if scope.where(project: nil).none?

    null_duration = scope.where(project: nil).duration_seconds
    return non_null if null_duration.zero?

    non_null.merge(nil => null_duration)
  end

  def grouped_durations(grouped, field, archived)
    stats = grouped.fetch(field, {})
    field == :project ? stats.reject { |project, _| archived.include?(project) } : stats
  end

  def weekly_project_stats(scope, timezone)
    week_ranges = week_ranges()
    result = week_ranges.to_h { |week_key, *_| [ week_key, {} ] }

    relation_sql = scope.with_valid_timestamps.where.not(time: nil).where(time: week_ranges.last[1]..week_ranges.first[2]).select(:time, :project).to_sql
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
                 ELSE LEAST(time - LAG(time) OVER (PARTITION BY project, #{week_group_sql} ORDER BY time), #{Heartbeat.heartbeat_timeout_duration.to_i})
               END AS diff
        FROM (#{relation_sql}) dashboard_heartbeats
      ) diffs
      GROUP BY week_group, grouped_time
      ORDER BY week_key DESC, grouped_time
    SQL

    rows.each { |row| result[row["week_key"]][row["grouped_time"]] = row["duration"].to_i }
    result
  end

  def rollup_records(raw, now:)
    records = [
      build_record(dimension: DashboardRollup::TOTAL_DIMENSION, bucket: nil, total_seconds: raw.total_time, now: now, source_heartbeats_count: raw.total_heartbeats, source_max_heartbeat_time: raw.source_max_heartbeat_time),
      build_record(dimension: DashboardRollup::FILTER_OPTIONS_DIMENSION, bucket: nil, total_seconds: 0, now: now, payload: raw.filter_options),
      build_record(dimension: DashboardRollup::ACTIVITY_GRAPH_DIMENSION, bucket: nil, total_seconds: 0, now: now, payload: raw.activity_graph),
      build_record(dimension: DashboardRollup::TODAY_STATS_DIMENSION, bucket: nil, total_seconds: 0, now: now, payload: raw.today_stats)
    ]

    GROUPED_DIMENSIONS.each do |dimension|
      raw.grouped_durations.fetch(dimension, {}).each do |bucket, total_seconds|
        records << build_record(dimension: dimension, bucket: bucket, total_seconds: total_seconds, now: now)
      end
    end

    raw.weekly_project_stats.each do |week_key, projects|
      projects.each do |project, total_seconds|
        records << build_record(dimension: WEEKLY_PROJECT_DIMENSION, bucket: [ week_key, project ].to_json, total_seconds: total_seconds, now: now)
      end
    end

    records
  end

  def build_record(dimension:, bucket:, total_seconds:, now:, source_heartbeats_count: nil, source_max_heartbeat_time: nil, payload: nil)
    {
      user_id: @user.id,
      dimension: dimension.to_s,
      bucket_value: bucket.to_s,
      bucket_value_present: !bucket.nil?,
      total_seconds: total_seconds.to_i,
      source_heartbeats_count: source_heartbeats_count,
      source_max_heartbeat_time: source_max_heartbeat_time,
      payload: payload,
      created_at: now,
      updated_at: now
    }
  end

  def rollup_eligible?
    @params[:interval].blank? && @params[:from].blank? && @params[:to].blank? && FILTERS.none? { |field| @params[field].present? }
  end

  def rollups_available?
    DashboardRollup.table_exists?
  rescue ActiveRecord::StatementInvalid
    false
  end

  def rollup_rows
    return [] unless rollups_available?

    @rollup_rows ||= DashboardRollup.where(user_id: @user.id).to_a
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
    DashboardRollup.dirty?(@user.id) || time_fingerprint(total_row.source_max_heartbeat_time) != time_fingerprint(@user.heartbeats.maximum(:time))
  end

  def activity_graph_rollup_valid?(row)
    payload = row&.payload
    return false unless payload.is_a?(Hash)

    start_date, end_date = activity_graph_date_range(@user.timezone)
    payload["timezone"] == @user.timezone &&
      payload["start_date"] == start_date &&
      payload["end_date"] == end_date &&
      payload["duration_by_date"].is_a?(Hash)
  end

  def today_stats_rollup_valid?(row)
    payload = row&.payload
    return false unless payload.is_a?(Hash)

    payload["timezone"] == @user.timezone &&
      payload["today_date"] == today_date &&
      payload.key?("todays_duration_seconds") &&
      payload["todays_language_categories"].is_a?(Array) &&
      payload["todays_editor_keys"].is_a?(Array)
  end

  def schedule_rollup_refresh(wait:)
    return if @rollup_refresh_scheduled

    DashboardRollupRefreshJob.schedule_for(@user.id, wait: wait)
    @rollup_refresh_scheduled = true
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

  def time_fingerprint(timestamp)
    return if timestamp.nil?

    (timestamp * 1_000_000).round
  end

  def today_date
    Time.use_zone(@user.timezone) { Date.current.iso8601 }
  end

  def activity_graph_date_range(timezone)
    Time.use_zone(timezone) { [ 365.days.ago.to_date.iso8601, Date.current.iso8601 ] }
  end

  def week_ranges
    Time.use_zone(@user.timezone) do
      (0..11).map do |week_offset|
        week_start = week_offset.weeks.ago.beginning_of_week
        [ week_start.to_date.iso8601, week_start.to_f, week_offset.weeks.ago.end_of_week.to_f ]
      end
    end
  end
end
