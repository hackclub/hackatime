module Api
  module Admin
    module V1
      class AdminController < Api::Admin::V1::ApplicationController
        include Api::Admin::V1::UserUtilities

        def check
          api_key = current_admin_api_key
          creator = User.find(api_key.user_id)

          render json: {
            valid: true,
            api_key: {
              id: api_key.id,
              name: api_key.name,
              created_at: api_key.created_at
            },
            creator: {
              id: creator.id,
              username: creator.username,
              display_name: creator.display_name,
              admin_level: creator.admin_level
            }
          }
        end

        def visualization_quantized
          user = find_user_by_id
          return unless user

          year = params[:year]
          month = params[:month]

          if year.blank? || month.blank?
            render json: { error: "invalid parameters" }, status: :unprocessable_entity
            return
          end

          result = ::Admin::VisualizationQuantizedQuery.new(
            user: user,
            year: year,
            month: month
          ).call

          unless result.success?
            error = result.error == :invalid_date ? "invalid date" : "invalid parameters"
            render json: { error: error }, status: :unprocessable_entity
            return
          end

          render json: { days: result.days }
        end

        def alt_candidates
          lookback_days = (params[:lookback_days] || 30).to_i.clamp(1, 365)
          cutoff = lookback_days.days.ago.to_i

          query = <<-SQL
            SELECT
                r1.user_id AS user_a_id,
                r2.user_id AS user_b_id,
                r1.machine,
                r1.ip_address,
                r1.first_seen as user_a_first_seen_on_combo,
                r1.last_seen as user_a_last_seen_on_combo,
                r2.first_seen as user_b_first_seen_on_combo,
                r2.last_seen as user_b_last_seen_on_combo
            FROM
                (
                    SELECT
                        user_id,
                        machine,
                        ip_address,
                        MIN(time) as first_seen,
                        MAX(time) as last_seen
                    FROM heartbeats
                    WHERE
                        user_id IS NOT NULL
                        AND machine IS NOT NULL
                        AND ip_address IS NOT NULL
                        AND time >= ?
                    GROUP BY 1, 2, 3
                ) r1
            JOIN
                (
                    SELECT
                        user_id,
                        machine,
                        ip_address,
                        MIN(time) as first_seen,
                        MAX(time) as last_seen
                    FROM heartbeats
                    WHERE
                        user_id IS NOT NULL
                        AND machine IS NOT NULL
                        AND ip_address IS NOT NULL
                        AND time >= ?
                    GROUP BY 1, 2, 3
                ) r2 ON r1.machine = r2.machine AND r1.ip_address = r2.ip_address
            WHERE
                r1.user_id < r2.user_id
            LIMIT 5000
          SQL

          result = ActiveRecord::Base.connection.exec_query(
            ActiveRecord::Base.sanitize_sql([ query, cutoff, cutoff ])
          )

          render json: { candidates: result.to_a }
        end

        def shared_machines
          lookback_days = (params[:lookback_days] || 30).to_i.clamp(1, 365)
          cutoff = lookback_days.days.ago.to_i

          query = <<-SQL
            SELECT
              sms.machine,
              sms.machine_frequency,
              ARRAY_AGG(DISTINCT u.id) AS user_ids
            FROM
              (
                SELECT
                  machine,
                  COUNT(user_id) AS machine_frequency,
                  ARRAY_AGG(user_id) AS user_ids
                FROM
                  (
                    SELECT DISTINCT
                      machine,
                      user_id
                    FROM
                      heartbeats
                    WHERE
                      machine IS NOT NULL
                      AND time > ?
                  ) AS UserMachines
                GROUP BY
                  machine
                HAVING
                  COUNT(user_id) > 1
              ) AS sms,
              LATERAL UNNEST(sms.user_ids) AS user_id_from_array
            JOIN
              users AS u ON u.id = user_id_from_array
            GROUP BY
              sms.machine,
              sms.machine_frequency
            ORDER BY
              sms.machine_frequency DESC
            LIMIT 5000
          SQL

          result = ActiveRecord::Base.connection.exec_query(
            ActiveRecord::Base.sanitize_sql([ query, cutoff ])
          )

          render json: { machines: result.to_a }
        end

        def active_users
          since_ts = params[:since].to_i
          min_ts = 90.days.ago.to_i

          if since_ts < 0
            render json: { error: "invalid since parameter" }, status: :unprocessable_entity
            return
          end

          since_ts = [ since_ts, min_ts ].max

          user_ids = Heartbeat
            .where("time >= ?", since_ts)
            .distinct
            .limit(50_000)
            .pluck(:user_id)

          render json: { user_ids: user_ids }
        end

        def audit_logs_counts
          user_ids_param = params[:user_ids]

          if user_ids_param.blank? || !user_ids_param.is_a?(Array)
            render json: { error: "user_ids array required" }, status: :unprocessable_entity
            return
          end

          user_ids = user_ids_param.take(1000)

          if user_ids.empty?
            render json: { error: "no valid user_ids provided" }, status: :unprocessable_entity
            return
          end

          query = <<-SQL
            SELECT
                user_id,
                COUNT(*) AS cnt
            FROM trust_level_audit_logs
            WHERE user_id IN (?)
            GROUP BY user_id
          SQL

          result = ActiveRecord::Base.connection.execute(
            ActiveRecord::Base.sanitize_sql([ query, user_ids ])
          )

          counts = result.each_with_object({}) do |row, hash|
            hash[row["user_id"].to_s] = row["cnt"]
          end

          user_ids.each do |id|
            counts[id.to_s] ||= 0
          end

          render json: { counts: counts }
        end

        def banned_users
          limit = [ params.fetch(:limit, 200).to_i, 1000 ].min
          offset = [ params.fetch(:offset, 0).to_i, 0 ].max

          banned = User.where(trust_level: User.trust_levels[:red])
            .left_joins(:email_addresses)
            .select("users.id, users.username, MIN(email_addresses.email) AS email")
            .group("users.id, users.username")
            .order("users.id")
            .limit(limit)
            .offset(offset)

          render json: {
            banned_users: banned.map { |u|
              { id: u.id, username: u.username, email: u.email || "no email" }
            }
          }
        end
      end
    end
  end
end
