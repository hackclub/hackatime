module DashboardData
  module Snapshots
    GROUPED_DIMENSIONS = %i[project language editor operating_system category].freeze
    WEEKLY_PROJECT_DIMENSION = "weekly_project".freeze
    # Keep indexed predecessor probes bounded; broad selections favour one scan.
    PREDECESSOR_LOOKUP_LIMIT = 1_000

    module_function

    def grouped_durations_snapshot(scope)
      GROUPED_DIMENSIONS.index_with do |field|
        field == :project ? project_grouped_durations(scope) : Heartbeat.attributed_durations_by(scope, field)
      end
    end

    def project_grouped_durations(scope)
      Heartbeat.attributed_durations_by(scope, :project, include_blank: true)
    end

    def project_details_snapshot(scope:, names: nil)
      attributed = Heartbeat.with_attributed_duration(scope)
      attributed = attributed.where(project: names) if names.present?
      relation_sql = attributed
        .where.not(project: [ nil, "" ])
        .select(:time, :project, :language, :duration)
        .to_sql

      rows = Heartbeat.connection.select_all(<<~SQL.squish)
        SELECT project AS grouped_time,
               COUNT(*)::integer AS heartbeat_count,
               MIN(time) AS first_heartbeat,
               MAX(time) AS last_heartbeat,
               ARRAY_REMOVE(ARRAY_AGG(DISTINCT NULLIF(language, '')), NULL) AS languages,
               COALESCE(SUM(duration), 0)::integer AS duration
        FROM (#{relation_sql}) project_detail_heartbeats
        GROUP BY project
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

      relation_sql = Heartbeat.with_attributed_duration(scope)
        .where(time: ranges.last[1]..ranges.first[2])
        .select(:time, :project, :duration)
        .to_sql

      quoted_timezone = Heartbeat.connection.quote(user.timezone)
      week_group_sql = "DATE_TRUNC('week', to_timestamp(time) AT TIME ZONE #{quoted_timezone})"

      rows = Heartbeat.connection.select_all(<<~SQL.squish)
        SELECT TO_CHAR(week_group, 'YYYY-MM-DD') AS week_key,
               grouped_time,
               COALESCE(SUM(duration), 0)::integer AS duration
        FROM (
          SELECT project AS grouped_time,
                 #{week_group_sql} AS week_group,
                 duration
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
          .map { |row| [ row["language"], row["language_count"].to_i ] }
          .reject { |language, _| language.blank? }
          .uniq
          .group_by { |language, _| language.categorize_language }
          .transform_values { |pairs| pairs.sum { |_, count| count } }
          .reject { |category, _| category.blank? }
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

    def coding_rhythm_snapshot(user:, scope:)
      relation_sql = scope.with_valid_timestamps.where.not(time: nil).select(:id, :time).to_sql
      quoted_timezone = Heartbeat.connection.quote(user.timezone)
      local_time_sql = "to_timestamp(time) AT TIME ZONE #{quoted_timezone}"
      timeout = Heartbeat.heartbeat_timeout_duration.to_i

      rows = Heartbeat.connection.select_all(<<~SQL.squish)
        SELECT weekday, hour, COALESCE(SUM(diff), 0)::integer AS duration
        FROM (
          SELECT EXTRACT(ISODOW FROM #{local_time_sql})::integer AS weekday,
                 EXTRACT(HOUR FROM #{local_time_sql})::integer AS hour,
                 CASE
                   WHEN LAG(time) OVER (ORDER BY time, id) IS NULL THEN 0
                   ELSE LEAST(time - LAG(time) OVER (ORDER BY time, id), #{timeout})
                 END AS diff
          FROM (#{relation_sql}) coding_rhythm_heartbeats
        ) diffs
        GROUP BY weekday, hour
        ORDER BY weekday, hour
      SQL

      {
        timezone: user.timezone,
        duration_by_slot: rows.to_h { |row| [ "#{row['weekday']}-#{row['hour']}", row["duration"].to_i ] }
      }
    end

    def coding_rhythm_result(payload, timezone:)
      durations = payload&.fetch("duration_by_slot", nil) || payload&.fetch(:duration_by_slot, nil) || {}
      {
        duration_by_slot: durations.transform_values(&:to_i),
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

    def adaptive_filtered_snapshot(user:, scope:)
      matches = yield scope.with_valid_timestamps
      attributed = if matches.reorder(nil).limit(PREDECESSOR_LOOKUP_LIMIT + 1).count <= PREDECESSOR_LOOKUP_LIMIT
        predecessor_dashboard_scope(timeline: scope, matches: matches)
      else
        yield attributed_dashboard_scope(scope)
      end
      filtered_query_snapshot(user: user, scope: attributed)
    end

    def predecessor_dashboard_scope(timeline:, matches:)
      current_sql = matches.reorder(nil).select(:id, :time, *GROUPED_DIMENSIONS).to_sql
      previous_sql = timeline.with_valid_timestamps
        .where("(heartbeats.time, heartbeats.id) < (current_heartbeat.time, current_heartbeat.id)")
        .reorder(time: :desc, id: :desc).limit(1).select(:time).to_sql
      timeout = Heartbeat.heartbeat_timeout_duration.to_i
      attributed_sql = <<~SQL.squish
        SELECT current_heartbeat.*,
               LEAST(COALESCE(current_heartbeat.time - previous_heartbeat.time, 0), #{timeout}) AS duration
        FROM (#{current_sql}) current_heartbeat
        LEFT JOIN LATERAL (#{previous_sql}) previous_heartbeat ON TRUE
      SQL
      Heartbeat.unscoped.from("(#{attributed_sql}) heartbeats")
    end

    # Date range and archive eligibility belong inside this window; dashboard
    # dimension filters belong outside it. Each gap belongs to the current row.
    def attributed_dashboard_scope(scope)
      Heartbeat.with_attributed_duration(scope)
    end

    def filtered_query_snapshot(user:, scope:)
      # Materialize after filtering so every aggregate reuses the same small set
      # of attributed rows instead of sorting/windowing the full timeline again.
      relation_sql = scope.select(:time, *GROUPED_DIMENSIONS, :duration).to_sql
      timezone = Heartbeat.connection.quote(user.timezone)
      local_time = "to_timestamp(time) AT TIME ZONE #{timezone}"
      ranges = week_ranges(user.timezone)
      week = "TO_CHAR(DATE_TRUNC('week', #{local_time}), 'YYYY-MM-DD')"
      slot = "CONCAT(EXTRACT(ISODOW FROM #{local_time})::integer, '-', EXTRACT(HOUR FROM #{local_time})::integer)"
      aggregates = [ <<~SQL.squish ]
        SELECT 'total' AS dimension, NULL::text AS bucket, NULL::text AS week_key,
               COALESCE(SUM(duration), 0) AS duration, COUNT(*) AS heartbeats
        FROM filtered
      SQL
      GROUPED_DIMENSIONS.each do |field|
        aggregates << <<~SQL.squish
          SELECT '#{field}', #{field}::text, NULL::text, SUM(duration), NULL::bigint
          FROM filtered GROUP BY #{field}
        SQL
      end
      aggregates << <<~SQL.squish
        SELECT 'weekly_project', project::text, #{week}, SUM(duration), NULL::bigint
        FROM filtered
        WHERE time BETWEEN #{Heartbeat.connection.quote(ranges.last[1])} AND #{Heartbeat.connection.quote(ranges.first[2])}
        GROUP BY #{week}, project
      SQL
      aggregates << <<~SQL.squish
        SELECT 'coding_rhythm', #{slot}, NULL::text, SUM(duration), NULL::bigint
        FROM filtered GROUP BY #{slot}
      SQL

      rows = Heartbeat.connection.select_all(<<~SQL.squish)
        WITH filtered AS MATERIALIZED (#{relation_sql})
        #{aggregates.join(' UNION ALL ')}
      SQL
      snapshot = {
        total_time: 0,
        total_heartbeats: 0,
        grouped_durations: GROUPED_DIMENSIONS.index_with { {} },
        weekly_project_stats: ranges.to_h { |key, *_| [ key, {} ] },
        coding_rhythm: { timezone: user.timezone, duration_by_slot: {} }
      }
      rows.each do |row|
        duration = row["duration"].to_i
        case row["dimension"]
        when "total"
          snapshot[:total_time] = duration
          snapshot[:total_heartbeats] = row["heartbeats"].to_i
        when "weekly_project"
          snapshot[:weekly_project_stats].fetch(row["week_key"])[row["bucket"]] = duration
        when "coding_rhythm"
          snapshot[:coding_rhythm][:duration_by_slot][row["bucket"]] = duration
        else
          snapshot[:grouped_durations].fetch(row["dimension"].to_sym)[row["bucket"]] = duration
        end
      end
      snapshot
    end

    # Live aggregate snapshot used by the unfiltered non-rollup dashboard path.
    # Returns the same shape as the rollup-derived aggregate snapshot.
    def aggregate_query_snapshot(user:, scope:)
      {
        total_time: scope.duration_seconds,
        total_heartbeats: scope.count,
        grouped_durations: grouped_durations_snapshot(scope),
        weekly_project_stats: weekly_project_stats(user: user, scope: scope),
        coding_rhythm: coding_rhythm_snapshot(user: user, scope: scope)
      }
    end

    # Reject project entries that should not appear in dashboard summaries.
    def grouped_durations_for(grouped_durations, field, archived)
      stats = grouped_durations.fetch(field, {})
      return stats unless field == :project

      stats.reject { |project, _| archived.include?(project) || ProjectNameUtils.broken?(project) }
    end

    # Fill aggregate display fields onto `result` from a snapshot.
    # `snapshot` must respond to fetch for: total_time, total_heartbeats, grouped_durations,
    # weekly_project_stats, and coding_rhythm.
    def fill_aggregate_result(result:, snapshot:, archived:, helpers:)
      grouped_durations = snapshot.fetch(:grouped_durations)
      weekly = snapshot.fetch(:weekly_project_stats)

      result[:total_time] = snapshot.fetch(:total_time)
      result[:total_heartbeats] = snapshot.fetch(:total_heartbeats)

      project_durations = grouped_durations_for(grouped_durations, :project, archived)
      result["top_project"] = project_durations.max_by { |_, duration| duration }&.first

      unless result["singular_project"]
        result[:project_durations] = project_durations.sort_by { |_, duration| -duration }.first(10).to_h
      end

      %i[language editor operating_system category].each do |field|
        # Chart and card totals must share display buckets because raw aliases collapse to one label.
        bucket_key = case field
        when :language then ->(raw) { raw.to_s.categorize_language }
        when :editor then ->(raw) { helpers.display_editor_name(raw) }
        when :operating_system then ->(raw) { helpers.display_os_name(raw) }
        else ->(raw) { raw.to_s }
        end

        stats = grouped_durations.fetch(field, {}).each_with_object({}) do |(raw, duration), agg|
          next if raw.to_s.blank?

          key = bucket_key.call(raw)
          next if key.to_s.blank?

          agg[key] = (agg[key] || 0) + duration
        end
        result[:coding_category_stats] = stats.slice("ai coding", "coding") if field == :category

        display_stats = stats.sort_by { |_, duration| -duration }.first(10).map { |key, value|
          label = field == :language ? helpers.display_language_name(key) : key
          [ label, value ]
        }.to_h
        result["top_#{field}"] = display_stats.keys.first
        result["#{field}_stats"] = display_stats unless result["singular_#{field}"]
      end

      if result["language_stats"].present?
        result[:language_colors] = LanguageUtils.colors_for(result["language_stats"].keys)
      end

      result[:weekly_project_stats] = weekly.transform_values do |stats|
        stats.reject { |project, _| archived.include?(project) || ProjectNameUtils.broken?(project) }
      end
      rhythm = snapshot.fetch(:coding_rhythm)
      result[:coding_rhythm] = coding_rhythm_result(
        rhythm,
        timezone: rhythm[:timezone] || rhythm["timezone"]
      )
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
