module Api
  module Admin
    module V1
      class HeartbeatsController < Api::Admin::V1::ApplicationController
        MAX_LIMIT = 10_000
        DEFAULT_LIMIT = 1_000
        ALT_CANDIDATES_LIMIT = 5_000
        MAX_LOOKBACK_DAYS = 365
        DEFAULT_LOOKBACK_DAYS = 30

        def ip_machine_pairs
          render json: { pairs: ip_machine_pair_rows(limit: parse_limit) }
        end

        def alt_candidates
          candidates = ip_machine_pair_rows(limit: ALT_CANDIDATES_LIMIT, inclusive_cutoff: true).map { |pair| serialize_alt_candidate(pair) }
          render json: { candidates: candidates }
        end

        def shared_machines
          limit = parse_limit
          cutoff = lookback_cutoff

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

        def ip_machine_pair_rows(limit:, inclusive_cutoff: false)
          cutoff_operator = inclusive_cutoff ? ">=" : ">"
          query = <<-SQL
            WITH user_machine_ip_activity AS (
              SELECT
                user_id,
                machine,
                ip_address,
                MIN(time) AS first_seen,
                MAX(time) AS last_seen
              FROM heartbeats
              WHERE user_id IS NOT NULL
                AND machine IS NOT NULL
                AND ip_address IS NOT NULL
                AND deleted_at IS NULL
                AND time #{cutoff_operator} ?
              GROUP BY user_id, machine, ip_address
            )
            SELECT
              r1.user_id AS user_a_id,
              r2.user_id AS user_b_id,
              r1.machine,
              r1.ip_address,
              r1.first_seen AS user_a_first_seen,
              r1.last_seen AS user_a_last_seen,
              r2.first_seen AS user_b_first_seen,
              r2.last_seen AS user_b_last_seen
            FROM user_machine_ip_activity r1
            JOIN user_machine_ip_activity r2
              ON r1.machine = r2.machine AND r1.ip_address = r2.ip_address
            WHERE r1.user_id < r2.user_id
            LIMIT ?
          SQL

          ActiveRecord::Base.connection.exec_query(
            ActiveRecord::Base.sanitize_sql([ query, lookback_cutoff, limit ])
          ).to_a
        end

        def serialize_alt_candidate(pair)
          {
            "user_a_id" => pair["user_a_id"],
            "user_b_id" => pair["user_b_id"],
            "machine" => pair["machine"],
            "ip_address" => pair["ip_address"],
            "user_a_first_seen_on_combo" => pair["user_a_first_seen"],
            "user_a_last_seen_on_combo" => pair["user_a_last_seen"],
            "user_b_first_seen_on_combo" => pair["user_b_first_seen"],
            "user_b_last_seen_on_combo" => pair["user_b_last_seen"]
          }
        end

        def lookback_cutoff
          lookback_days = (params[:lookback_days] || DEFAULT_LOOKBACK_DAYS).to_i.clamp(1, MAX_LOOKBACK_DAYS)
          lookback_days.days.ago.to_i
        end

        def parse_limit
          return DEFAULT_LIMIT unless params[:limit].present?

          parsed = params[:limit].to_i
          parsed.positive? ? parsed.clamp(1, MAX_LIMIT) : DEFAULT_LIMIT
        end
      end
    end
  end
end
