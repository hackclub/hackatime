module DashboardData
  module Snapshots
    GROUPED_DIMENSIONS = %i[project language editor operating_system category].freeze
    WEEKLY_PROJECT_DIMENSION = "weekly_project".freeze

    module_function

    def grouped_durations_snapshot(scope)
      GROUPED_DIMENSIONS.index_with do |field|
        field == :project ? project_grouped_durations(scope) : Heartbeat.attributed_durations_by(scope, field)
      end
    end

    def project_grouped_durations(scope)
      non_null = scope.where.not(project: nil).group(:project).duration_seconds
      return non_null if scope.where(project: nil).none?

      null_duration = scope.where(project: nil).duration_seconds
      return non_null if null_duration.zero?

      non_null.merge(nil => null_duration)
    end

    def project_details_snapshot(scope:)
      timeout = Heartbeat.heartbeat_timeout_duration.to_i
      relation_sql = scope.with_valid_timestamps
        .where.not(project: [ nil, "" ], time: nil)
        .select(:id, :time, :project, :language)
        .to_sql

      rows = Heartbeat.connection.select_all(<<~SQL.squish)
        SELECT grouped_time,
               COUNT(*)::integer AS heartbeat_count,
               MIN(time) AS first_heartbeat,
               MAX(time) AS last_heartbeat,
               ARRAY_REMOVE(ARRAY_AGG(DISTINCT NULLIF(language, '')), NULL) AS languages,
               COALESCE(SUM(diff), 0)::integer AS duration
        FROM (
          SELECT project AS grouped_time,
                 time,
                 language,
                 CASE
                   WHEN LAG(time) OVER (PARTITION BY project ORDER BY time, id) IS NULL THEN 0
                   ELSE LEAST(time - LAG(time) OVER (PARTITION BY project ORDER BY time, id), #{timeout})
                 END AS diff
          FROM (#{relation_sql}) project_detail_heartbeats
        ) diffs
        GROUP BY grouped_time
      SQL

      rows.each_with_object({}) do |row, result|
        result[row["grouped_time"]] = {
          total_seconds: row["duration"].to_i,
          total_heartbeats: row["heartbeat_count"].to_i,
          first_heartbeat: row["first_heartbeat"],
          last_heartbeat: row["last_heartbeat"],
          languages: pg_array(row["languages"]).compact_blank
        }
      end
    end

    def pg_array(value)
      return value if value.is_a?(Array)
      return [] if value.blank?

      value.to_s.delete_prefix("{").delete_suffix("}").split(",")
    end

    def weekly_project_stats(user:, scope:)
      ranges = week_ranges(user.timezone)
      result = ranges.to_h { |week_key, *_| [ week_key, {} ] }

      relation_sql = scope.with_valid_timestamps
        .where.not(time: nil)
        .where(time: ranges.last[1]..ranges.first[2])
        .select(:id, :time, :project)
        .to_sql

      quoted_timezone = Heartbeat.connection.quote(user.timezone)
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

    def today_stats_snapshot(user:, scope:)
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
          timezone: user.timezone,
          today_date: Date.current.iso8601,
          todays_duration_seconds: scope.today.duration_seconds.to_i,
          todays_language_categories: language_categories,
          todays_editor_keys: editor_keys
        }
      end
    end

    def activity_graph_snapshot(user:, scope:)
      Time.use_zone(user.timezone) do
        start_date, end_date = activity_graph_date_range(user.timezone)
        durations = scope.daily_durations(user_timezone: user.timezone).to_h

        {
          timezone: user.timezone,
          start_date: start_date,
          end_date: end_date,
          duration_by_date: durations.transform_keys { |date| date.to_date.iso8601 }.transform_values(&:to_i)
        }
      end
    end

    def activity_graph_result(start_date:, end_date:, duration_by_date:, timezone:)
      {
        start_date: start_date,
        end_date: end_date,
        duration_by_date: duration_by_date.to_h.transform_keys { |date| date.to_s }.transform_values(&:to_i),
        busiest_day_seconds: 8.hours.to_i,
        timezone_label: ActiveSupport::TimeZone[timezone]&.to_s || timezone
      }
    end

    def week_ranges(timezone)
      Time.use_zone(timezone) do
        (0..11).map do |week_offset|
          week_start = week_offset.weeks.ago.beginning_of_week
          [ week_start.to_date.iso8601, week_start.to_f, week_offset.weeks.ago.end_of_week.to_f ]
        end
      end
    end

    def activity_graph_date_range(timezone)
      Time.use_zone(timezone) do
        [ 365.days.ago.to_date.iso8601, Date.current.iso8601 ]
      end
    end
  end
end
