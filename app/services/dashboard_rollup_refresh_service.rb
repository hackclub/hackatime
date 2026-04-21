class DashboardRollupRefreshService < ApplicationService
  GROUPED_DIMENSIONS = %i[project language editor operating_system category].freeze
  WEEKLY_PROJECT_DIMENSION = "weekly_project".freeze

  def initialize(user:)
    @user = user
    @scope = user.heartbeats
  end

  def call
    now = Time.current
    records = [
      build_total_record(now),
      build_filter_options_record(now),
      build_activity_graph_record(now),
      build_today_stats_record(now)
    ]

    GROUPED_DIMENSIONS.each do |dimension|
      grouped_durations(dimension).each do |bucket, total_seconds|
        records << build_record(
          dimension: dimension,
          bucket: bucket,
          total_seconds: total_seconds,
          now: now
        )
      end
    end
    weekly_project_stats.each do |week_key, projects|
      projects.each do |project, total_seconds|
        records << build_record(
          dimension: WEEKLY_PROJECT_DIMENSION,
          bucket: [ week_key, project ].to_json,
          total_seconds: total_seconds,
          now: now
        )
      end
    end

    DashboardRollup.transaction do
      DashboardRollup.where(user_id: @user.id).delete_all
      DashboardRollup.insert_all!(records)
    end

    DashboardRollup.clear_dirty(@user.id)
    @user.recalculate_and_store_streak!
  end

  private

  def build_total_record(now)
    build_record(
      dimension: DashboardRollup::TOTAL_DIMENSION,
      bucket: nil,
      total_seconds: @scope.duration_seconds,
      now: now,
      source_heartbeats_count: @scope.count,
      source_max_heartbeat_time: @scope.maximum(:time)
    )
  end

  def build_activity_graph_record(now)
    build_record(
      dimension: DashboardRollup::ACTIVITY_GRAPH_DIMENSION,
      bucket: nil,
      total_seconds: 0,
      now: now,
      payload: activity_graph_payload
    )
  end

  def build_filter_options_record(now)
    build_record(
      dimension: DashboardRollup::FILTER_OPTIONS_DIMENSION,
      bucket: nil,
      total_seconds: 0,
      now: now,
      payload: filter_options_payload
    )
  end

  def build_today_stats_record(now)
    build_record(
      dimension: DashboardRollup::TODAY_STATS_DIMENSION,
      bucket: nil,
      total_seconds: 0,
      now: now,
      payload: today_stats_payload
    )
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

  def grouped_durations(dimension)
    return project_grouped_durations if dimension == :project

    @scope.group(dimension).duration_seconds
  end

  def project_grouped_durations
    non_null = @scope.where.not(project: nil).group(:project).duration_seconds
    return non_null if @scope.where(project: nil).none?

    null_duration = @scope.where(project: nil).duration_seconds
    return non_null if null_duration.zero?

    non_null.merge(nil => null_duration)
  end

  def weekly_project_stats
    week_ranges = dashboard_week_ranges
    result = week_ranges.to_h { |week_key, *_| [ week_key, {} ] }

    relation_sql = @scope.with_valid_timestamps
      .where.not(time: nil)
      .where(time: week_ranges.last[1]..week_ranges.first[2])
      .select(:time, :project)
      .to_sql

    quoted_timezone = Heartbeat.connection.quote(@user.timezone)
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
    Time.use_zone(@user.timezone) do
      (0..11).map do |w|
        week_start = w.weeks.ago.beginning_of_week
        [ week_start.to_date.iso8601, week_start.to_f, w.weeks.ago.end_of_week.to_f ]
      end
    end
  end

  def activity_graph_payload
    Time.use_zone(@user.timezone) do
      end_date = Date.current
      start_date = 365.days.ago.to_date
      durations = @scope.daily_durations(user_timezone: @user.timezone).to_h

      {
        timezone: @user.timezone,
        start_date: start_date.iso8601,
        end_date: end_date.iso8601,
        duration_by_date: durations.transform_keys { |date| date.to_date.iso8601 }.transform_values(&:to_i)
      }
    end
  end

  def filter_options_payload
    GROUPED_DIMENSIONS.index_with do |dimension|
      @scope.distinct.pluck(dimension).compact_blank.sort
    end
  end

  def today_stats_payload
    Time.use_zone(@user.timezone) do
      rows = @scope.today
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
        todays_duration_seconds: @scope.today.duration_seconds.to_i,
        todays_language_categories: language_categories,
        todays_editor_keys: editor_keys
      }
    end
  end
end
