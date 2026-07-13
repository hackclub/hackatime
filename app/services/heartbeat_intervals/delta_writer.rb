module HeartbeatIntervals
  class DeltaWriter
    DIMENSION_SECONDS_COLUMNS = {
      project: "project_seconds_delta",
      language: "language_seconds_delta",
      editor: "editor_seconds_delta",
      operating_system: "operating_system_seconds_delta",
      machine: "machine_seconds_delta",
      category: "category_seconds_delta",
      entity: "entity_seconds_delta",
      branch: "branch_seconds_delta"
    }.freeze
    VALID_TIME_RANGE = 0..253402300799

    def self.emit_for_inserted_rows(rows, reason:)
      new(rows, reason: reason).call
    end

    def initialize(rows, reason:)
      @rows = rows.map { |row| row.transform_keys(&:to_s) }
      @reason = reason
    end

    def call
      load_batched_previous_times if live_rows.many?
      deltas = live_rows.map { |row| delta_for(row) }
      Clickhouse::HeartbeatIntervalDelta.insert_all(deltas) if deltas.any?
      deltas
    end

    private

    attr_reader :rows, :reason

    def live_rows
      @live_rows ||= rows.reject { |row| row["deleted_at"].present? || row["time"].nil? }
        .select { |row| VALID_TIME_RANGE.cover?(row["time"].to_f) }
        .sort_by { |row| [ row["user_id"].to_i, row["time"].to_f, row["id"].to_i ] }
    end

    def delta_for(row)
      now = Time.current
      delta = {
        delta_id: Clickhouse::HeartbeatWriter.generate_id(now),
        user_id: row["user_id"].to_i,
        day: Time.at(row["time"].to_f).utc.to_date,
        time: row["time"].to_f,
        project: row["project"].to_s,
        language: clean_filter_dimension(row["language"]),
        editor: clean_filter_dimension(row["editor"]),
        operating_system: clean_filter_dimension(row["operating_system"]),
        machine: clean_filter_dimension(row["machine"]),
        category: clean_filter_dimension(row["category"]),
        entity: clean_filter_dimension(row["entity"]),
        branch: clean_filter_dimension(row["branch"]),
        heartbeat_count_delta: 1,
        reason: reason,
        created_at: now
      }

      user_seconds, user_first_seconds = interval_since_previous(row)
      delta[:user_seconds_delta] = user_seconds
      delta[:user_first_seconds_delta] = user_first_seconds
      DIMENSION_SECONDS_COLUMNS.each do |dimension, seconds_column|
        seconds, first_seconds = dimension_interval(row, dimension)
        delta[seconds_column] = seconds
        delta[seconds_column.sub("_seconds_", "_first_seconds_")] = first_seconds
      end

      delta
    end

    def dimension_interval(row, dimension)
      value = row[dimension.to_s]
      return [ 0, 0 ] if dimension == :project && value.blank?

      interval_since_previous(row, dimension => value)
    end

    def interval_since_previous(row, conditions = {})
      previous_time = previous_time_for(row, conditions)
      return [ 0, 0 ] unless previous_time

      diff = row["time"].to_f - previous_time.to_f
      return [ 0, 0 ] if diff <= 0

      seconds = [ diff, Clickhouse::Heartbeat.heartbeat_timeout_duration.to_i ].min
      first_in_day = Time.at(previous_time.to_f).utc.to_date != Time.at(row["time"].to_f).utc.to_date
      [ seconds, first_in_day ? seconds : 0 ]
    end

    def previous_time_for(row, conditions)
      if defined?(@batched_previous_times)
        dimension, value = conditions.first || [ :user, nil ]
        key = partition_key(row["user_id"], dimension, value)
        return @batched_previous_times[key].tap { @batched_previous_times[key] = row["time"].to_f }
      end

      scope = Clickhouse::Heartbeat.unscoped.final
        .where(deleted_at: nil, user_id: row["user_id"].to_i)
        .with_valid_timestamps
        .where("time < ? OR (time = ? AND id < ?)", row["time"].to_f, row["time"].to_f, row["id"].to_i)

      conditions.each { |field, value| scope = scope.where(field => value) }

      scope.order(time: :desc, id: :desc).limit(1).pick(:time)
    end

    def load_batched_previous_times
      @batched_previous_times = {}
      rows = Clickhouse::Heartbeat.connection.select_all(<<~SQL.squish)
        SELECT user_id,
               partition_value.1 AS dimension,
               partition_value.2 AS value,
               argMax(time, tuple(time, id)) AS previous_time
        FROM (
          SELECT user_id,
                 time,
                 id,
                 arrayJoin([#{partition_array_sql}]) AS partition_value
          FROM #{heartbeat_table} FINAL
          WHERE deleted_at IS NULL
            AND time >= #{VALID_TIME_RANGE.begin}
            AND time <= #{VALID_TIME_RANGE.end}
            AND (#{cutoff_conditions_sql})
        ) AS candidate_predecessors
        WHERE (user_id, partition_value.1, partition_value.2) IN (#{requested_partition_keys_sql})
        GROUP BY user_id, dimension, value
      SQL

      rows.each do |row|
        @batched_previous_times[partition_key(row["user_id"], row["dimension"], row["value"])] = row["previous_time"].to_f
      end
    end

    def partition_array_sql
      dimensions = DIMENSION_SECONDS_COLUMNS.keys.map do |dimension|
        value = if dimension == :project
          "ifNull(project, '')"
        else
          "ifNull(#{dimension}, #{connection.quote(HeartbeatIntervals::NULL_DIMENSION_VALUE)})"
        end
        "tuple(#{connection.quote(dimension.to_s)}, #{value})"
      end
      ([ "tuple('user', '')" ] + dimensions).join(", ")
    end

    def cutoff_conditions_sql
      live_rows.group_by { |row| row["user_id"].to_i }.map do |user_id, user_rows|
        cutoff = user_rows.min_by { |row| [ row["time"].to_f, row["id"].to_i ] }.fetch("time").to_f
        "(user_id = #{user_id} AND time < #{connection.quote(cutoff)})"
      end.join(" OR ")
    end

    def requested_partition_keys_sql
      keys = live_rows.flat_map do |row|
        user_key = partition_key(row["user_id"], :user, nil)
        dimension_keys = DIMENSION_SECONDS_COLUMNS.keys.filter_map do |dimension|
          value = row[dimension.to_s]
          next if dimension == :project && value.blank?

          partition_key(row["user_id"], dimension, value)
        end
        [ user_key, *dimension_keys ]
      end.uniq

      keys.map do |user_id, dimension, value|
        "(#{user_id}, #{connection.quote(dimension)}, #{connection.quote(value)})"
      end.join(", ")
    end

    def partition_key(user_id, dimension, value)
      normalized_value = if dimension.to_sym == :user
        ""
      elsif dimension.to_sym == :project
        value.to_s
      else
        clean_filter_dimension(value)
      end
      [ user_id.to_i, dimension.to_s, normalized_value ]
    end

    def connection
      Clickhouse::Heartbeat.connection
    end

    def heartbeat_table
      connection.quote_table_name(Clickhouse::Heartbeat.table_name)
    end

    def clean_filter_dimension(value)
      value.nil? ? HeartbeatIntervals::NULL_DIMENSION_VALUE : value.to_s
    end
  end
end
