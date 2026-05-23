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

      PG::TextDecoder::Array.new.decode(value.to_s)
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
        timeout = Heartbeat.heartbeat_timeout_duration.to_i
        today_sql = scope.today.to_sql

        rows = Heartbeat.connection.select_all(<<~SQL.squish).to_a
          WITH today_rows AS (#{today_sql}),
               duration_calc AS (
                 SELECT
                   CASE WHEN LAG(time) OVER (ORDER BY time, id) IS NULL THEN 0
                        ELSE LEAST(time - LAG(time) OVER (ORDER BY time, id), #{timeout}) END AS diff
                 FROM today_rows
                 WHERE time IS NOT NULL AND time >= 0 AND time <= 253402300799
               ),
               total_duration AS (SELECT COALESCE(SUM(diff), 0)::integer AS total FROM duration_calc)
          SELECT DISTINCT
            language,
            editor,
            COUNT(*) OVER (PARTITION BY language) AS language_count,
            COUNT(*) OVER (PARTITION BY editor) AS editor_count,
            (SELECT total FROM total_duration) AS total_duration
          FROM today_rows
        SQL

        language_categories = rows
          .map { |row| [ row["language"]&.categorize_language, row["language_count"].to_i ] }
          .reject { |language, _| language.blank? }
          .group_by(&:first)
          .transform_values { |pairs| pairs.sum(&:last) }
          .sort_by { |_, count| -count }
          .map(&:first)

        editor_keys = rows
          .map { |row| [ row["editor"], row["editor_count"].to_i ] }
          .reject { |editor, _| editor.blank? }
          .uniq
          .sort_by { |_, count| -count }
          .map(&:first)

        {
          timezone: user.timezone,
          today_date: Date.current.iso8601,
          todays_duration_seconds: rows.first&.fetch("total_duration").to_i,
          todays_language_categories: language_categories,
          todays_editor_keys: editor_keys
        }
      end
    end

    def activity_graph_snapshot(user:, scope:)
      start_date, end_date = activity_graph_date_range(user.timezone)
      durations = Time.use_zone(user.timezone) { scope.daily_durations(user_timezone: user.timezone).to_h }

      {
        timezone: user.timezone,
        start_date: start_date,
        end_date: end_date,
        duration_by_date: durations.transform_keys { |date| date.to_date.iso8601 }.transform_values(&:to_i)
      }
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

    # Live aggregate snapshot used by the filtered (non-rollup) dashboard path.
    # Returns the same shape as the rollup-derived aggregate snapshot.
    def aggregate_query_snapshot(user:, scope:)
      {
        total_time: scope.duration_seconds,
        total_heartbeats: scope.count,
        grouped_durations: grouped_durations_snapshot(scope),
        weekly_project_stats: weekly_project_stats(user: user, scope: scope)
      }
    end

    # Reject archived project entries from a `{ project => duration }` map.
    def grouped_durations_for(grouped_durations, field, archived)
      stats = grouped_durations.fetch(field, {})
      return stats unless field == :project

      stats.reject { |project, _| archived.include?(project) }
    end

    # Fill aggregate display fields onto `result` from a snapshot.
    # `snapshot` must respond to fetch for: total_time, total_heartbeats, grouped_durations, weekly_project_stats.
    def fill_aggregate_result(result:, snapshot:, archived:, helpers:)
      grouped_durations = snapshot.fetch(:grouped_durations)
      weekly = snapshot.fetch(:weekly_project_stats)

      result[:total_time] = snapshot.fetch(:total_time)
      result[:total_heartbeats] = snapshot.fetch(:total_heartbeats)

      GROUPED_DIMENSIONS.each do |field|
        stats = grouped_durations_for(grouped_durations, field, archived)
        result["top_#{field}"] = stats.max_by { |_, duration| duration }&.first
      end

      result["top_editor"] &&= helpers.display_editor_name(result["top_editor"])
      result["top_operating_system"] &&= helpers.display_os_name(result["top_operating_system"])
      result["top_language"] &&= helpers.display_language_name(result["top_language"])

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
          when :editor then helpers.display_editor_name(key)
          when :operating_system then helpers.display_os_name(key)
          when :language then helpers.display_language_name(key)
          else key
          end
          [ label, value ]
        }.to_h
      end

      if result["language_stats"].present?
        result[:language_colors] = LanguageUtils.colors_for(result["language_stats"].keys)
      end

      result[:weekly_project_stats] = weekly.transform_values do |stats|
        stats.reject { |project, _| archived.include?(project) }
      end
    end

    def today_stats_display(snapshot_or_payload, helpers:)
      payload = snapshot_or_payload || {}
      duration = (payload[:todays_duration_seconds] || payload["todays_duration_seconds"]).to_i
      language_categories = payload[:todays_language_categories] || payload["todays_language_categories"]
      editor_keys = payload[:todays_editor_keys] || payload["todays_editor_keys"]

      todays_languages = Array(language_categories).filter_map do |language|
        helpers.display_language_name(language) if language.present?
      end
      todays_editors = Array(editor_keys).filter_map do |editor|
        helpers.display_editor_name(editor) if editor.present?
      end

      {
        show_logged_time_sentence: duration > 1.minute && (todays_languages.any? || todays_editors.any?),
        todays_duration_display: helpers.short_time_detailed(duration),
        todays_languages: todays_languages,
        todays_editors: todays_editors
      }
    end
  end
end
