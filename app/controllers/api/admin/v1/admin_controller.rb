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

          year = params[:year]&.to_i
          month = params[:month]&.to_i

          if year.nil? || month.nil? || month < 1 || month > 12
            render json: { error: "invalid parameters" }, status: :unprocessable_entity
            return
          end

          begin
            start_epoch = Time.utc(year, month, 1).to_i
            end_epoch = if month == 12
              Time.utc(year + 1, 1, 1).to_i
            else
              Time.utc(year, month + 1, 1).to_i
            end
          rescue Date::Error
            render json: { error: "invalid date" }, status: :unprocessable_entity
            return
          end

          quantized_query = <<-SQL
            WITH base_heartbeats AS (
                SELECT
                    time,
                    lineno,
                    cursorpos,
                    toDate(toDateTime(toUInt32(time))) as day_start
                FROM heartbeats
                WHERE user_id = ?
                AND time >= ? AND time <= ?
                AND (lineno IS NOT NULL OR cursorpos IS NOT NULL)
                LIMIT 1000000
            ),
            daily_stats AS (
                SELECT
                    *,
                    greatest(1, max(lineno) OVER (PARTITION BY day_start)) as max_lineno,
                    greatest(1, max(cursorpos) OVER (PARTITION BY day_start)) as max_cursorpos
                FROM base_heartbeats
            ),
            quantized_heartbeats AS (
                SELECT
                    *,
                    round(2 + ((time - toUInt32(toDateTime(day_start))) / 86400) * (396)) as qx,
                    round(2 + (1 - CAST(lineno AS Float64) / max_lineno) * (96)) as qy_lineno,
                    round(2 + (1 - CAST(cursorpos AS Float64) / max_cursorpos) * (96)) as qy_cursorpos
                FROM daily_stats
            )
            SELECT time, lineno, cursorpos
            FROM (
                SELECT
                    any(time) AS time,
                    any(lineno) AS lineno,
                    any(cursorpos) AS cursorpos
                FROM quantized_heartbeats
                WHERE lineno IS NOT NULL
                GROUP BY day_start, qx, qy_lineno
            ) AS lineno_pixels
            UNION ALL
            SELECT time, lineno, cursorpos
            FROM (
                SELECT
                    any(time) AS time,
                    any(lineno) AS lineno,
                    any(cursorpos) AS cursorpos
                FROM quantized_heartbeats
                WHERE cursorpos IS NOT NULL
                GROUP BY day_start, qx, qy_cursorpos
            ) AS cursorpos_pixels
            ORDER BY time ASC
          SQL

          daily_totals_query = <<-SQL
            WITH heartbeats_with_gaps AS (
              SELECT
                toDate(toDateTime(toUInt32(time))) as day,
                time - lagInFrame(time, 1, time) OVER (PARTITION BY toDate(toDateTime(toUInt32(time))) ORDER BY time) as gap
              FROM heartbeats
              WHERE user_id = ? AND time >= ? AND time <= ?
            )
            SELECT
              day,
              SUM(least(gap, 120)) as total_seconds
            FROM heartbeats_with_gaps
            WHERE gap IS NOT NULL
            GROUP BY day
          SQL

          quantized_result = Heartbeat.connection.select_all(
            Heartbeat.sanitize_sql([ quantized_query, user.id, start_epoch, end_epoch ])
          )

          daily_totals_result = Heartbeat.connection.select_all(
            Heartbeat.sanitize_sql([ daily_totals_query, user.id, start_epoch, end_epoch ])
          )

          daily_totals = daily_totals_result.each_with_object({}) do |row, hash|
            day = row["day"]
            total_seconds = row["total_seconds"]
            hash[day] = total_seconds
          end

          points_by_day = quantized_result.each_with_object({}) do |row, hash|
            day = Time.at(row["time"]).to_date
            hash[day] ||= []
            hash[day] << {
              time: row["time"],
              lineno: row["lineno"],
              cursorpos: row["cursorpos"]
            }
          end

          days = (start_epoch...end_epoch).step(86400).map do |epoch|
            day = Time.at(epoch).to_date
            {
              date_timestamp_s: epoch,
              total_seconds: daily_totals[day] || 0,
              points: points_by_day[day] || []
            }
          end

          render json: { days: days }
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

          result = Heartbeat.connection.select_all(
            Heartbeat.sanitize_sql([ query, cutoff, cutoff ])
          )

          render json: { candidates: result.to_a }
        end

        def shared_machines
          lookback_days = (params[:lookback_days] || 30).to_i.clamp(1, 365)
          cutoff = lookback_days.days.ago.to_i

          query = <<-SQL
            SELECT
              machine,
              uniq(user_id) AS machine_frequency,
              groupArray(DISTINCT user_id) AS user_ids
            FROM heartbeats
            WHERE machine != '' AND machine IS NOT NULL
              AND time > ?
            GROUP BY machine
            HAVING uniq(user_id) > 1
            ORDER BY machine_frequency DESC
            LIMIT 5000
          SQL

          result = Heartbeat.connection.select_all(
            Heartbeat.sanitize_sql([ query, cutoff ])
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
