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

          combos = <<~SQL
            SELECT user_id, machine, ip_address,
                   min(time) AS first_seen, max(time) AS last_seen,
                   toBool(min(#{HeartbeatExclusion.hidden_sql})) AS hidden
            FROM heartbeats
            WHERE machine IS NOT NULL
              AND ip_address IS NOT NULL
              AND deleted_at IS NULL
              AND time > #{Integer(cutoff)}
            GROUP BY user_id, machine, ip_address
          SQL

          rows = Heartbeat.connection.select_all(<<~SQL).to_a
            #{HeartbeatExclusion::INCLUDE_HIDDEN_COMMENT}
            WITH combos AS (#{combos})
            SELECT
              r1.user_id  AS user_a_id,
              r2.user_id  AS user_b_id,
              r1.machine AS machine,
              r1.ip_address AS ip_address,
              r1.first_seen AS user_a_first_seen,
              r1.last_seen  AS user_a_last_seen,
              r2.first_seen AS user_b_first_seen,
              r2.last_seen  AS user_b_last_seen,
              r1.hidden     AS user_a_hidden,
              r2.hidden     AS user_b_hidden
            FROM combos AS r1
            INNER JOIN combos AS r2 ON r1.machine = r2.machine AND r1.ip_address = r2.ip_address
            WHERE r1.user_id < r2.user_id
            LIMIT #{Integer(limit)}
          SQL

          render json: { pairs: rows }
        end

        def shared_machines
          lookback_days = (params[:lookback_days] || 30).to_i.clamp(1, 365)
          limit = parse_limit
          cutoff = lookback_days.days.ago.to_i

          rows = Heartbeat.connection.select_all(<<~SQL).to_a
            #{HeartbeatExclusion::INCLUDE_HIDDEN_COMMENT}
            WITH user_machines AS (
              SELECT machine, user_id, toBool(min(#{HeartbeatExclusion.hidden_sql})) AS hidden
              FROM heartbeats
              WHERE machine IS NOT NULL
                AND deleted_at IS NULL
                AND time > #{Integer(cutoff)}
              GROUP BY machine, user_id
            )
            SELECT
              machine,
              count() AS machine_frequency,
              arraySort(groupArray(user_id)) AS user_ids,
              arraySort(groupArrayIf(user_id, hidden)) AS hidden_user_ids
            FROM user_machines
            GROUP BY machine
            HAVING count() > 1
            ORDER BY machine_frequency DESC, machine ASC
            LIMIT #{Integer(limit)}
          SQL

          # Keep the Postgres array text format ("{1,2}") existing clients parse.
          machines = rows.map do |row|
            row.merge(%w[user_ids hidden_user_ids].to_h { |key| [ key, "{#{row.fetch(key).join(',')}}" ] })
          end
          render json: { machines: }
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
