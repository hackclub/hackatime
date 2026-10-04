# Per-user dashboard rollup stored in ClickHouse (see the CreateHeartbeatRollups
# ClickHouse migration). Derived data: rebuilt from
# heartbeats by DashboardRollupRefreshJob and read only through the generation
# published in HeartbeatRollupState.
class HeartbeatRollup < ClickhouseRecord
  DIMENSIONS = %i[project language editor operating_system category].freeze
  Sql = Heartbeatable::DurationSql

  GROUP_COLUMNS = %w[project language editor operating_system category slot week graph_date today_language today_editor].freeze
  GROUPING_SETS = {
    total: [],
    project: %w[project],
    language: %w[language],
    editor: %w[editor],
    operating_system: %w[operating_system],
    category: %w[category],
    coding_rhythm: %w[slot],
    weekly_project: %w[week project],
    activity_graph: %w[graph_date],
    today_language: %w[today_language],
    today_editor: %w[today_editor]
  }.freeze
  # ClickHouse's GROUPING() sets a bit for every column that is NOT grouped.
  SET_BY_MASK = GROUPING_SETS.to_h { |name, columns|
    mask = GROUP_COLUMNS.each_with_index.sum { |column, index| columns.include?(column) ? 0 : 1 << (GROUP_COLUMNS.size - 1 - index) }
    [ mask, name ]
  }.freeze

  class << self
    # Builds the user's rollup as a new generation, publishes it and removes
    # older generations. Returns false if a newer generation was published first.
    def rebuild!(user)
      generation = Process.clock_gettime(Process::CLOCK_REALTIME, :microsecond)
      timezone = user.timezone
      # Read before building so an exclusion change during the build leaves the
      # published version stale rather than silently skipped.
      heartbeat_cache_version = user.heartbeat_cache_version

      insert_generation!(user:, generation:, timezone:)
      published = HeartbeatRollupState.publish!(user_id: user.id, generation:, timezone:, heartbeat_cache_version:)
      delete_generations!(user.id, published ? "generation < #{generation}" : "generation = #{generation}")
      published
    end

    # Everything the unfiltered dashboard renders, in the shapes produced by
    # DashboardData::Snapshots, read from one generation in one query.
    def dashboard_snapshot(state)
      timezone = state.timezone
      week_ranges = DashboardData::Snapshots.week_ranges(timezone)
      graph_start, today = DashboardData::Snapshots.activity_graph_date_range(timezone)

      snapshot = {
        total_time: 0,
        total_heartbeats: 0,
        grouped_durations: DIMENSIONS.index_with { {} },
        weekly_project_stats: week_ranges.to_h { |key, *_| [ key, {} ] },
        coding_rhythm: { timezone:, duration_by_slot: {} },
        filter_options: DIMENSIONS.index_with { [] },
        activity_graph: { timezone:, start_date: graph_start, end_date: today, duration_by_date: {} },
        project_details: {}
      }
      today_seconds = 0
      today_language_counts = {}
      today_editor_counts = {}

      snapshot_rows(state:, today:, graph_start:, week_start: week_ranges.last.first).each do |row|
        values = GROUP_COLUMNS.zip(row[1, GROUP_COLUMNS.size]).to_h
        seconds, project_seconds, day_seconds, project_week_seconds, heartbeat_count, first_time, last_time, languages, todays =
          row[(GROUP_COLUMNS.size + 1)..]

        case SET_BY_MASK.fetch(row[0])
        when :total
          # sum() over no rows is NULL (aggregate_functions_null_for_empty).
          snapshot[:total_time] = seconds.to_i
          snapshot[:total_heartbeats] = heartbeat_count.to_i
          today_seconds = todays.to_i
        when :project
          project = values["project"]
          snapshot[:grouped_durations][:project][project] = project_seconds unless project.nil? && project_seconds.zero?
          snapshot[:filter_options][:project] << project
          if project.present?
            snapshot[:project_details][project] = {
              total_seconds: project_seconds,
              total_heartbeats: heartbeat_count,
              first_heartbeat: first_time,
              last_heartbeat: last_time,
              languages: Array(languages)
            }
          end
        when :language, :editor, :operating_system, :category
          dimension = SET_BY_MASK.fetch(row[0])
          value = values[dimension.to_s]
          next if value.blank?

          snapshot[:grouped_durations][dimension][value] = seconds
          snapshot[:filter_options][dimension] << value
        when :coding_rhythm
          snapshot[:coding_rhythm][:duration_by_slot][values["slot"]] = seconds
        when :weekly_project
          week = snapshot[:weekly_project_stats][values["week"]]
          week[values["project"]] = project_week_seconds if week
        when :activity_graph
          snapshot[:activity_graph][:duration_by_date][values["graph_date"]] = day_seconds if values["graph_date"]
        when :today_language
          today_language_counts[values["today_language"]] = heartbeat_count
        when :today_editor
          today_editor_counts[values["today_editor"]] = heartbeat_count
        end
      end

      snapshot[:filter_options].transform_values! { |options| options.compact_blank.sort }
      snapshot[:today_stats] = DashboardData::Snapshots.today_stats_payload(
        timezone:, today_date: today, duration_seconds: today_seconds,
        language_counts: today_language_counts, editor_counts: today_editor_counts
      )
      snapshot
    end

    # Users with tracked time and their total seconds, from each user's newest
    # generation. Shared site-wide for a minute.
    def site_totals
      Rails.cache.fetch("heartbeat_rollups/site_totals", expires_in: Heartbeat::SITE_ACTIVITY_CACHE_TTL) do
        users_tracked, seconds_tracked = connection.select_rows(<<~SQL.squish).first
          SELECT countIf(user_seconds > 0), sum(user_seconds)
          FROM (
            SELECT user_id, argMax(generation_seconds, generation) AS user_seconds
            FROM (
              SELECT user_id, generation, toInt64(round(sum(duration))) AS generation_seconds
              FROM #{quoted_table_name}
              GROUP BY user_id, generation
            )
            GROUP BY user_id
          )
        SQL
        { users_tracked: users_tracked.to_i, seconds_tracked: seconds_tracked.to_i }
      end
    end

    private

    def insert_generation!(user:, generation:, timezone:)
      timeout = Heartbeat.heartbeat_timeout_duration.to_i
      source = user.heartbeats_excluding_archived_projects.with_valid_timestamps
        .unscope(:order, :select).select(:id, :time, *DIMENSIONS)
      dimensions = DIMENSIONS.join(", ")

      sql = <<~SQL.squish
        INSERT INTO #{quoted_table_name}
          (user_id, generation, local_date, hour, #{dimensions}, heartbeats,
           duration, project_duration, day_duration, project_week_duration, first_time, last_time)
        SELECT #{Integer(user.id)}, #{Integer(generation)}, local_date, hour, #{dimensions}, count(),
               sum(gap), sum(project_gap), sum(day_gap), sum(project_week_gap), min(time), max(time)
        FROM (
          SELECT time, #{dimensions}, toDate32(local_time) AS local_date, toHour(local_time) AS hour,
                 #{Sql.capped_gap(timeout, window: 'w')} AS gap,
                 #{Sql.capped_gap(timeout, window: 'wp')} AS project_gap,
                 #{Sql.capped_gap(timeout, window: 'wd')} AS day_gap,
                 #{Sql.capped_gap(timeout, window: 'wpw')} AS project_week_gap
          FROM (
            SELECT *, #{Sql.local_datetime(timezone)} AS local_time
            FROM (#{source.to_sql}) AS source_heartbeats
          ) AS local_heartbeats
          WINDOW w AS #{Sql.window},
                 wp AS #{Sql.window(:project)},
                 wd AS #{Sql.window('toDate32(local_time)')},
                 wpw AS #{Sql.window(%w[project toMonday(local_time)])}
        )
        GROUP BY local_date, hour, #{dimensions}
      SQL

      with_clickhouse_settings(**ClickhouseRecord::SYNC_INSERT_SETTINGS) do
        connection.with_response_format(nil) { connection.execute(sql) }
      end
    end

    # Lightweight delete written as a patch part, so frequent rebuilds never
    # queue heavyweight mutations.
    def delete_generations!(user_id, condition)
      connection.with_response_format(nil) do
        connection.execute(<<~SQL.squish)
          DELETE FROM #{quoted_table_name} WHERE user_id = #{Integer(user_id)} AND #{condition}
          SETTINGS lightweight_delete_mode = 'lightweight_update_force'
        SQL
      end
    end

    def snapshot_rows(state:, today:, graph_start:, week_start:)
      is_today = "local_date = toDate(#{quote_clickhouse(today)})"

      connection.select_rows(<<~SQL.squish)
        SELECT grouping(#{GROUP_COLUMNS.join(', ')}) AS set_mask, #{GROUP_COLUMNS.join(', ')},
               toInt64(round(sum(duration))) AS seconds,
               toInt64(round(sum(project_duration))) AS project_seconds,
               toInt64(round(sum(day_duration))) AS day_seconds,
               toInt64(round(sum(project_week_duration))) AS project_week_seconds,
               toInt64(sum(heartbeats)) AS heartbeat_count,
               min(first_time) AS first_heartbeat,
               max(last_time) AS last_heartbeat,
               arraySort(groupUniqArrayIf(language, language != '')) AS project_languages,
               toInt64(round(sumIf(day_duration, #{is_today}))) AS today_seconds
        FROM (
          SELECT *,
                 concat(toString(toDayOfWeek(local_date)), '-', toString(hour)) AS slot,
                 if(local_date >= toDate(#{quote_clickhouse(week_start)}), toString(toMonday(local_date)), NULL) AS week,
                 if(local_date BETWEEN toDate(#{quote_clickhouse(graph_start)}) AND toDate(#{quote_clickhouse(today)}), toString(local_date), NULL) AS graph_date,
                 if(#{is_today}, language, NULL) AS today_language,
                 if(#{is_today}, editor, NULL) AS today_editor
          FROM #{quoted_table_name}
          WHERE user_id = #{Integer(state.user_id)} AND generation = #{Integer(state.generation)}
        )
        GROUP BY GROUPING SETS (#{GROUPING_SETS.values.map { |columns| "(#{columns.join(', ')})" }.join(', ')})
      SQL
    end
  end
end
