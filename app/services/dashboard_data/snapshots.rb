module DashboardData
  # Dashboard aggregates computed live from ClickHouse heartbeats.
  #
  # Duration semantics are unchanged from the Postgres implementation (see
  # Heartbeatable::DurationSql): each heartbeat contributes the capped gap since
  # the previous heartbeat in its partition, the first row contributes zero, and
  # rows are ordered by (time, id).
  module Snapshots
    GROUPED_DIMENSIONS = %i[project language editor operating_system category].freeze

    Sql = Heartbeatable::DurationSql

    module_function

    def timeout = Heartbeat.heartbeat_timeout_duration.to_i
    def connection = Heartbeat.connection

    def grouped_durations_snapshot(scope)
      GROUPED_DIMENSIONS.index_with do |field|
        field == :project ? project_grouped_durations(scope) : Heartbeat.attributed_durations_by(scope, field)
      end
    end

    # Project durations partition gaps by project (a gap only counts between two
    # heartbeats of the same project). NULL project is its own bucket.
    def project_grouped_durations(scope)
      durations = scope.group(:project).duration_seconds
      durations.delete(nil) if durations[nil].to_i.zero?
      durations
    end

    def project_details_snapshot(scope:)
      inner = scope.with_valid_timestamps.where.not(project: [ nil, "" ]).unscope(:order, :select)
        .select(:id, :time, :project, :language)

      rows = connection.select_rows(<<~SQL.squish)
        SELECT project,
               count() AS heartbeat_count,
               min(time) AS first_heartbeat,
               max(time) AS last_heartbeat,
               arraySort(groupUniqArrayIf(language, language IS NOT NULL AND language != '')) AS languages,
               #{Sql.to_seconds('sum(gap)')} AS duration
        FROM (
          SELECT project, time, language, #{Sql.capped_gap(timeout)} AS gap
          FROM (#{inner.to_sql}) AS project_detail_heartbeats
          WINDOW w AS #{Sql.window(:project)}
        )
        GROUP BY project
      SQL

      rows.each_with_object({}) do |(project, count, first, last, languages, duration), result|
        # The adapter returns Float64 aggregates as BigDecimal; keep epoch floats.
        result[project] = {
          total_seconds: duration.to_i,
          total_heartbeats: count.to_i,
          first_heartbeat: first&.to_f,
          last_heartbeat: last&.to_f,
          languages: Array(languages).compact_blank
        }
      end
    end

    def weekly_project_stats(user:, scope:)
      ranges = week_ranges(user.timezone)
      result = ranges.to_h { |week_key, *_| [ week_key, {} ] }
      week = "toMonday(#{Sql.local_datetime(user.timezone)})"

      inner = scope.with_valid_timestamps.unscope(:order, :select)
        .where(time: ranges.last[1]..ranges.first[2])
        .select(:id, :time, :project)

      connection.select_rows(<<~SQL.squish).each do |week_key, project, duration|
        SELECT toString(week) AS week_key, project, #{Sql.to_seconds('sum(gap)')} AS duration
        FROM (
          SELECT project, #{week} AS week, #{Sql.capped_gap(timeout)} AS gap
          FROM (#{inner.to_sql}) AS weekly_heartbeats
          WINDOW w AS #{Sql.window([ :project, week ])}
        )
        GROUP BY week, project
      SQL
        result[week_key][project] = duration.to_i if result.key?(week_key)
      end

      result
    end

    def today_stats_snapshot(user:, scope:)
      Time.use_zone(user.timezone) do
        today = scope.today.with_valid_timestamps.unscope(:order, :select)
        counts = today.unscope(:select).group(:language, :editor).count

        language_counts = Hash.new(0)
        editor_counts = Hash.new(0)
        counts.each do |(language, editor), count|
          language_counts[language] += count
          editor_counts[editor] += count
        end

        today_stats_payload(
          timezone: user.timezone, today_date: Date.current.iso8601, duration_seconds: Heartbeat.duration_seconds(today),
          language_counts:, editor_counts:
        )
      end
    end

    # Today's duration plus language categories and editors, most used first.
    def today_stats_payload(timezone:, today_date:, duration_seconds:, language_counts:, editor_counts:)
      language_categories = language_counts
        .reject { |language, _| language.blank? }
        .group_by { |language, _| language.categorize_language }
        .transform_values { |pairs| pairs.sum { |_, count| count } }
        .reject { |category, _| category.blank? }
        .sort_by { |_, count| -count }
        .map(&:first)

      editor_keys = editor_counts
        .reject { |editor, _| editor.blank? }
        .sort_by { |_, count| -count }
        .map(&:first)

      {
        timezone: timezone,
        today_date: today_date,
        todays_duration_seconds: duration_seconds,
        todays_language_categories: language_categories,
        todays_editor_keys: editor_keys
      }
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

    # Hour-of-week heatmap. Gaps are global (ordered over the whole scope) and
    # attributed to the local weekday/hour of the heartbeat that ends them.
    def coding_rhythm_snapshot(user:, scope:)
      local = Sql.local_datetime(user.timezone)
      inner = scope.with_valid_timestamps.unscope(:order, :select).select(:id, :time)

      rows = connection.select_rows(<<~SQL.squish)
        SELECT weekday, hour, #{Sql.to_seconds('sum(gap)')} AS duration
        FROM (
          SELECT toDayOfWeek(#{local}) AS weekday, toHour(#{local}) AS hour, #{Sql.capped_gap(timeout)} AS gap
          FROM (#{inner.to_sql}) AS rhythm_heartbeats
          WINDOW w AS #{Sql.window}
        )
        GROUP BY weekday, hour
      SQL

      {
        timezone: user.timezone,
        duration_by_slot: rows.to_h { |weekday, hour, duration| [ "#{weekday}-#{hour}", duration.to_i ] }
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

    # Filtered dashboard (project/language/editor/OS/category filters). The date
    # range and archive/visibility eligibility sit INSIDE the gap window (they
    # define the timeline); dimension filters apply AFTER it, so each kept
    # heartbeat keeps the gap to the previous heartbeat on the whole timeline.
    # Every aggregate the dashboard renders comes from one ClickHouse query.
    #
    # `scope` is the timeline; the block narrows it to the filtered heartbeats
    # and its where-clause is reused as the post-window filter.
    def adaptive_filtered_snapshot(user:, scope:)
      timeline = scope.with_valid_timestamps
      # The block may narrow its relation in place (where!), so give it a copy.
      filtered = yield timeline.spawn
      filter_sql = post_window_filter_sql(timeline, filtered)
      filtered_query_snapshot(user:, scope: timeline, filter_sql:)
    end

    # The extra WHERE conditions the filtered relation adds on top of the timeline.
    def post_window_filter_sql(timeline, filtered)
      extra = filtered.where_clause - timeline.where_clause
      return "1" if extra.empty?

      # Column references stay qualified as heartbeats.<column>; the filtered
      # query names its timeline subquery `heartbeats` so they resolve.
      connection.to_sql(extra.ast)
    end

    def filtered_query_snapshot(user:, scope:, filter_sql: "1")
      local = Sql.local_datetime(user.timezone)
      ranges = week_ranges(user.timezone)
      week_from, week_to = ranges.last[1], ranges.first[2]
      inner = scope.unscope(:order, :select).select(:id, :time, *GROUPED_DIMENSIONS)

      keys = [
        "('total', NULL, NULL)",
        *GROUPED_DIMENSIONS.map { |field| "('#{field}', #{field}, NULL)" },
        "if(time BETWEEN #{week_from} AND #{week_to}, ('weekly_project', project, toString(toMonday(#{local}))), ('skip', NULL, NULL))",
        "('coding_rhythm', concat(toString(toDayOfWeek(#{local})), '-', toString(toHour(#{local}))), NULL)"
      ]

      rows = connection.select_rows(<<~SQL.squish)
        SELECT key.1 AS dimension, key.2 AS bucket, key.3 AS week_key,
               #{Sql.to_seconds('sum(gap)')} AS duration, count() AS heartbeat_count
        FROM (
          SELECT * FROM (
            SELECT time, #{GROUPED_DIMENSIONS.join(', ')}, #{Sql.capped_gap(timeout)} AS gap
            FROM (#{inner.to_sql}) AS timeline_heartbeats
            WINDOW w AS #{Sql.window}
          ) AS heartbeats
          WHERE #{filter_sql}
        )
        ARRAY JOIN [#{keys.join(', ')}] AS key
        WHERE key.1 != 'skip'
        GROUP BY key
      SQL

      snapshot = {
        total_time: 0,
        total_heartbeats: 0,
        grouped_durations: GROUPED_DIMENSIONS.index_with { {} },
        weekly_project_stats: ranges.to_h { |key, *_| [ key, {} ] },
        coding_rhythm: { timezone: user.timezone, duration_by_slot: {} }
      }
      rows.each do |dimension, bucket, week_key, duration, heartbeats|
        duration = duration.to_i
        case dimension
        when "total"
          snapshot[:total_time] = duration
          snapshot[:total_heartbeats] = heartbeats.to_i
        when "weekly_project"
          snapshot[:weekly_project_stats][week_key][bucket] = duration if snapshot[:weekly_project_stats].key?(week_key)
        when "coding_rhythm"
          snapshot[:coding_rhythm][:duration_by_slot][bucket] = duration
        else
          snapshot[:grouped_durations].fetch(dimension.to_sym)[bucket] = duration
        end
      end
      snapshot
    end

    # Live aggregate snapshot used by the unfiltered non-rollup dashboard path.
    # Returns the same shape as the rollup-derived aggregate snapshot.
    def aggregate_query_snapshot(user:, scope:)
      {
        total_time: scope.duration_seconds,
        total_heartbeats: scope.with_valid_timestamps.count,
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
