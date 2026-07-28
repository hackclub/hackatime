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
              r2.last_seen  AS user_b_last_seen
            FROM (
              SELECT user_id, machine, ip_address,
                     MIN(time) AS first_seen, MAX(time) AS last_seen
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
                     MIN(time) AS first_seen, MAX(time) AS last_seen
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
            SELECT
              sms.machine,
              sms.machine_frequency,
              ARRAY_AGG(DISTINCT u.id) AS user_ids
            FROM (
              SELECT machine, COUNT(user_id) AS machine_frequency
              FROM (
                SELECT DISTINCT machine, user_id
                FROM heartbeats
                WHERE machine IS NOT NULL
                  AND deleted_at IS NULL
                  AND time > ?
              ) AS user_machines
              GROUP BY machine
              HAVING COUNT(user_id) > 1
            ) AS sms
            JOIN heartbeats hb ON hb.machine = sms.machine AND hb.deleted_at IS NULL AND hb.time > ?
            JOIN users u ON u.id = hb.user_id
            GROUP BY sms.machine, sms.machine_frequency
            ORDER BY sms.machine_frequency DESC, sms.machine ASC
            LIMIT ?
          SQL

          result = ActiveRecord::Base.connection.exec_query(
            ActiveRecord::Base.sanitize_sql([ query, cutoff, cutoff, limit ])
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
