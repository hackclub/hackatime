module DashboardData
  module Snapshots
    GROUPED_DIMENSIONS = %i[project language editor operating_system category].freeze
    WEEKLY_PROJECT_DIMENSION = "weekly_project".freeze

    module_function

    def grouped_durations_snapshot(scope)
      GROUPED_DIMENSIONS.index_with do |field|
        field == :project ? project_grouped_durations(scope) : scope.klass.attributed_durations_by(scope, field)
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
      timeout = Clickhouse::Heartbeat.heartbeat_timeout_duration.to_i
      relation_sql = scope.with_valid_timestamps
        .where.not(project: [ nil, "" ])
        .where.not(time: nil)
        .select(:id, :time, :project, :language)
        .to_sql

      rows = Clickhouse::Heartbeat.connection.select_all(<<~SQL.squish)
        SELECT grouped_time,
               COUNT(*) AS heartbeat_count,
               MIN(time) AS first_heartbeat,
               MAX(time) AS last_heartbeat,
               groupUniqArrayIf(assumeNotNull(language), language IS NOT NULL AND language != '') AS languages,
               SUM(diff) AS duration
        FROM (
          SELECT project AS grouped_time,
                 time,
                 language,
                 least(time - lagInFrame(time, 1, time) OVER (PARTITION BY project ORDER BY time, id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), #{timeout}) AS diff
          FROM (#{relation_sql}) AS project_detail_heartbeats
        ) AS diffs
        GROUP BY grouped_time
      SQL

      rows.each_with_object({}) do |row, result|
        result[row["grouped_time"]] = {
          total_seconds: row["duration"].to_f.round,
          total_heartbeats: row["heartbeat_count"].to_i,
          first_heartbeat: row["first_heartbeat"],
          last_heartbeat: row["last_heartbeat"],
          languages: Array(row["languages"]).compact_blank
        }
      end
    end

    def weekly_project_stats(user:, scope:)
      ranges = week_ranges(user.timezone)
      result = ranges.to_h { |week_key, *_| [ week_key, {} ] }

      relation_sql = scope.with_valid_timestamps
        .where.not(time: nil)
        .where(time: ranges.last[1]..ranges.first[2])
        .select(:id, :time, :project)
        .to_sql

      quoted_timezone = Clickhouse::Heartbeat.connection.quote(user.timezone)
      week_group_sql = "toMonday(toTimeZone(toDateTime64(time, 3), #{quoted_timezone}))"
      lag_sql = "lagInFrame(time, 1, time) OVER (PARTITION BY project, #{week_group_sql} ORDER BY time, id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)"

      rows = Clickhouse::Heartbeat.connection.select_all(<<~SQL.squish)
        SELECT toString(week_group) AS week_key,
               grouped_time,
               SUM(diff) AS duration
        FROM (
          SELECT project AS grouped_time,
                 #{week_group_sql} AS week_group,
                 least(time - #{lag_sql}, #{Clickhouse::Heartbeat.heartbeat_timeout_duration.to_i}) AS diff
          FROM (#{relation_sql}) AS dashboard_heartbeats
        ) AS diffs
        GROUP BY week_group, grouped_time
        ORDER BY week_key DESC, grouped_time
      SQL

      rows.each do |row|
        result[row["week_key"]][row["grouped_time"]] = row["duration"].to_f.round
      end

      result
    end

    def today_stats_snapshot(user:, scope:)
      Time.use_zone(user.timezone) do
        today_scope = scope.today

        language_categories = today_scope.group(:language).count
          .reject { |language, _| language.blank? }
          .group_by { |(language, _)| language.categorize_language }
          .transform_values { |pairs| pairs.sum { |_, count| count } }
          .reject { |category, _| category.blank? }
          .sort_by { |_, count| -count }
          .map(&:first)

        editor_keys = today_scope.group(:editor).count
          .reject { |editor, _| editor.blank? }
          .sort_by { |_, count| -count }
          .map(&:first)

        {
          timezone: user.timezone,
          today_date: Date.current.iso8601,
          todays_duration_seconds: today_scope.duration_seconds.to_i,
          todays_language_categories: language_categories,
          todays_editor_keys: editor_keys
        }
      rescue ActiveRecord::ActiveRecordError => e
        raise unless e.message.include?("undefined method 'map' for nil")

        {
          timezone: user.timezone,
          today_date: Date.current.iso8601,
          todays_duration_seconds: 0,
          todays_language_categories: [],
          todays_editor_keys: []
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

    def aggregate_query_snapshot(user:, scope:)
      {
        total_time: scope.duration_seconds,
        total_heartbeats: scope.count,
        grouped_durations: grouped_durations_snapshot(scope),
        weekly_project_stats: weekly_project_stats(user: user, scope: scope)
      }
    rescue ActiveRecord::ActiveRecordError => e
      raise unless e.message.include?("undefined method 'map' for nil")

      {
        total_time: 0,
        total_heartbeats: 0,
        grouped_durations: GROUPED_DIMENSIONS.index_with { {} },
        weekly_project_stats: week_ranges(user.timezone).to_h { |week_key, *_| [ week_key, {} ] }
      }
    end

    # Reject project entries that should not appear in dashboard summaries.
    def grouped_durations_for(grouped_durations, field, archived)
      stats = grouped_durations.fetch(field, {})
      return stats unless field == :project

      stats.reject { |project, _| archived.include?(project) || ProjectNameUtils.broken?(project) }
    end

    # Fill aggregate display fields onto `result` from a snapshot.
    # `snapshot` must respond to fetch for: total_time, total_heartbeats, grouped_durations, weekly_project_stats.
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
