module HeartbeatIntervals
  class UserRebuilder
    REBUILD_READ_TIMEOUT = 30.minutes.to_i
    REBUILD_SETTINGS = {
      max_threads: 1,
      max_bytes_before_external_sort: 64.megabytes,
      max_bytes_before_external_group_by: 64.megabytes
    }.freeze

    DIMENSION_COLUMNS = HeartbeatIntervals::DIMENSIONS.map(&:to_s).freeze
    SECONDS_COLUMNS = ([ "user_seconds_delta", "user_first_seconds_delta" ] + DIMENSION_COLUMNS.flat_map do |dimension|
      [ "#{dimension}_seconds_delta", "#{dimension}_first_seconds_delta" ]
    end).freeze

    DELTA_COLUMNS = (SECONDS_COLUMNS + %w[heartbeat_count_delta]).freeze
    GROUP_COLUMNS = (%w[user_id day time] + DIMENSION_COLUMNS).freeze
    INSERT_COLUMNS = ([ "delta_id" ] + GROUP_COLUMNS + DELTA_COLUMNS + %w[reason created_at]).freeze

    def self.call(user_id:, reason:)
      new(user_id: user_id, reason: reason).call
    end

    def initialize(user_id:, reason:)
      @user_id = user_id.to_i
      @reason = reason
    end

    def call
      HeartbeatIntervals::UserLock.call(user_ids: [ user_id ]) do
        connection.with_clickhouse_read_timeout(REBUILD_READ_TIMEOUT) do
          connection.with_settings(**REBUILD_SETTINGS) do
            existing_deltas? ? write_net_corrections : write_initial_facts
          end
        end
      end
      true
    end

    private

    attr_reader :user_id, :reason

    def existing_deltas?
      connection.select_value("SELECT 1 FROM #{delta_table} WHERE user_id = #{user_id} LIMIT 1").present?
    end

    def write_initial_facts
      reason_sql = connection.quote(reason)
      connection.execute(<<~SQL.squish)
        INSERT INTO #{delta_table} (#{INSERT_COLUMNS.join(", ")})
        SELECT cityHash64(#{GROUP_COLUMNS.join(", ")}, #{reason_sql}, now64(6)) AS delta_id,
               #{GROUP_COLUMNS.join(", ")},
               #{DELTA_COLUMNS.join(", ")},
               #{reason_sql} AS reason,
               now64(6, 'UTC') AS created_at
        FROM (#{canonical_facts_sql}) AS canonical_facts
      SQL
    end

    def write_net_corrections
      reason_sql = connection.quote(reason)
      existing_retractions = DELTA_COLUMNS.map { |column| "-sum(#{column}) AS #{column}" }
      net_corrections = DELTA_COLUMNS.map { |column| "sum(#{column}) AS #{column}" }
      nonzero = DELTA_COLUMNS.map { |column| "#{column} != 0" }.join(" OR ")

      connection.execute(<<~SQL.squish)
        INSERT INTO #{delta_table} (#{INSERT_COLUMNS.join(", ")})
        SELECT cityHash64(#{GROUP_COLUMNS.join(", ")}, #{reason_sql}, now64(6)) AS delta_id,
               #{GROUP_COLUMNS.join(", ")},
               #{net_corrections.join(", ")},
               #{reason_sql} AS reason,
               now64(6, 'UTC') AS created_at
        FROM (
          SELECT #{GROUP_COLUMNS.join(", ")},
                 #{existing_retractions.join(", ")}
          FROM #{delta_table}
          WHERE user_id = #{user_id}
          GROUP BY #{GROUP_COLUMNS.join(", ")}

          UNION ALL

          #{canonical_facts_sql}
        ) AS correction_candidates
        GROUP BY #{GROUP_COLUMNS.join(", ")}
        HAVING #{nonzero}
      SQL
    end

    def canonical_facts_sql
      <<~SQL.squish
        SELECT user_id,
               toDate(toDateTime64(time, 3, 'UTC')) AS day,
               time,
               #{DIMENSION_COLUMNS.join(", ")},
               #{interval_selects.join(", ")},
               1 AS heartbeat_count_delta
        FROM (
          SELECT id,
                 user_id,
                 time,
                 #{dimension_selects.join(", ")},
                 #{previous_time_selects.join(", ")}
          FROM #{heartbeat_table} FINAL
          WHERE user_id = #{user_id}
            AND deleted_at IS NULL
            AND time >= #{HeartbeatIntervals::VALID_TIME_RANGE.begin}
            AND time <= #{HeartbeatIntervals::VALID_TIME_RANGE.end}
        ) AS canonical_heartbeats
      SQL
    end

    def interval_selects
      timeout = Clickhouse::Heartbeat.heartbeat_timeout_duration.to_i
      interval_specs.flat_map do |name, _dimension|
        previous = "#{name}_previous_time"
        seconds = "#{name}_seconds_delta"
        [
          "if(time > #{previous}, least(time - #{previous}, #{timeout}), 0) AS #{seconds}",
          "if(toDate(toDateTime64(time, 3, 'UTC')) != toDate(toDateTime64(#{previous}, 3, 'UTC')), #{seconds}, 0) AS #{name}_first_seconds_delta"
        ]
      end
    end

    def interval_specs
      { "user" => nil }.merge(DIMENSION_COLUMNS.index_with(&:itself))
    end

    def previous_time_selects
      interval_specs.map do |name, dimension|
        partition = dimension ? "user_id, #{normalized_dimension_sql(dimension)}" : "user_id"
        "lagInFrame(time, 1, time) OVER (PARTITION BY #{partition} ORDER BY time, id " \
          "ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS #{name}_previous_time"
      end
    end

    def dimension_selects
      DIMENSION_COLUMNS.map { |dimension| "#{normalized_dimension_sql(dimension)} AS #{dimension}" }
    end

    def normalized_dimension_sql(dimension)
      return "ifNull(project, '')" if dimension == "project"

      "ifNull(#{dimension}, #{connection.quote(HeartbeatIntervals::NULL_DIMENSION_VALUE)})"
    end

    def connection
      Clickhouse::HeartbeatIntervalDelta.connection
    end

    def delta_table
      connection.quote_table_name(Clickhouse::HeartbeatIntervalDelta.table_name)
    end

    def heartbeat_table
      connection.quote_table_name(Clickhouse::Heartbeat.table_name)
    end
  end
end
