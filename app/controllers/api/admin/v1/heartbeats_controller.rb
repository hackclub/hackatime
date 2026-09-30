module Api
  module Admin
    module V1
      class HeartbeatsController < Api::Admin::V1::ApplicationController
        MAX_LIMIT = 10_000
        DEFAULT_LIMIT = 1_000

        def ip_machine_pairs
          lookback_days = (params[:lookback_days] || 30).to_i.clamp(1, 365)
          limit = parse_limit
          cutoff = lookback_days.days.ago.to_i

          query = <<-SQL
            SELECT
              r1.user_id  AS user_a_id,
              r2.user_id  AS user_b_id,
              r1.machine,
              r1.ip_address,
              r1.first_seen AS user_a_first_seen,
              r1.last_seen  AS user_a_last_seen,
              r2.first_seen AS user_b_first_seen,
              r2.last_seen  AS user_b_last_seen,
              r1.hidden     AS user_a_hidden,
              r2.hidden     AS user_b_hidden
            FROM (
              SELECT user_id, machine, ip_address,
                     MIN(time) AS first_seen, MAX(time) AS last_seen,
                     BOOL_AND(#{HeartbeatExclusion::HIDDEN_SQL}) AS hidden
              FROM heartbeats
              WHERE user_id IS NOT NULL
                AND machine IS NOT NULL
                AND ip_address IS NOT NULL
                AND deleted_at IS NULL
                AND time > ?
              GROUP BY user_id, machine, ip_address
            ) r1
            JOIN (
              SELECT user_id, machine, ip_address,
                     MIN(time) AS first_seen, MAX(time) AS last_seen,
                     BOOL_AND(#{HeartbeatExclusion::HIDDEN_SQL}) AS hidden
              FROM heartbeats
              WHERE user_id IS NOT NULL
                AND machine IS NOT NULL
                AND ip_address IS NOT NULL
                AND deleted_at IS NULL
                AND time > ?
              GROUP BY user_id, machine, ip_address
            ) r2 ON r1.machine = r2.machine AND r1.ip_address = r2.ip_address
            WHERE r1.user_id < r2.user_id
            LIMIT ?
          SQL

          result = ActiveRecord::Base.connection.exec_query(
            ActiveRecord::Base.sanitize_sql([ query, cutoff, cutoff, limit ])
          )

          render json: { pairs: result.to_a }
        end

        def shared_machines
          lookback_days = (params[:lookback_days] || 30).to_i.clamp(1, 365)
          limit = parse_limit
          cutoff = lookback_days.days.ago.to_i

          query = <<-SQL
            WITH user_machines AS (
              SELECT machine, user_id, BOOL_AND(#{HeartbeatExclusion::HIDDEN_SQL}) AS hidden
              FROM heartbeats
              WHERE machine IS NOT NULL
                AND deleted_at IS NULL
                AND time > ?
              GROUP BY machine, user_id
            ),
            shared AS (
              SELECT machine, COUNT(user_id) AS machine_frequency
              FROM user_machines
              GROUP BY machine
              HAVING COUNT(user_id) > 1
            )
            SELECT
              shared.machine,
              shared.machine_frequency,
              ARRAY_AGG(u.id ORDER BY u.id) AS user_ids,
              COALESCE(ARRAY_AGG(u.id ORDER BY u.id) FILTER (WHERE user_machines.hidden), '{}') AS hidden_user_ids
            FROM shared
            JOIN user_machines ON user_machines.machine = shared.machine
            JOIN users u ON u.id = user_machines.user_id
            GROUP BY shared.machine, shared.machine_frequency
            ORDER BY shared.machine_frequency DESC, shared.machine ASC
            LIMIT ?
          SQL

          result = ActiveRecord::Base.connection.exec_query(
            ActiveRecord::Base.sanitize_sql([ query, cutoff, limit ])
          )

          render json: { machines: result.to_a }
        end

        private

        def parse_limit
          return DEFAULT_LIMIT unless params[:limit].present?

          parsed = params[:limit].to_i
          parsed.positive? ? parsed.clamp(1, MAX_LIMIT) : DEFAULT_LIMIT
        end
      end
    end
  end
end
