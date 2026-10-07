module Api
  module Admin
    module V1
      class AdminController < Api::Admin::V1::ApplicationController
        include Api::Admin::V1::UserUtilities

        def check
          u = current_user
          body = {
            valid: true,
            creator: {
              id: u.id,
              username: u.username,
              display_name: u.display_name,
              admin_level: u.admin_level
            }
          }

          if (k = current_admin_api_key)
            body[:auth] = { type: "api_key" }
            body[:api_key] = { id: k.id, name: k.name, created_at: k.created_at }
          elsif (t = current_oauth_token)
            a = t.application
            body[:auth] = {
              type: "oauth",
              application: { id: a&.id, name: a&.name, uid: a&.uid },
              scopes: t.scopes.to_a
            }
          end

          render json: body
        end

        def visualization_quantized
          user = find_user_by_id
          return unless user

          year = params[:year]&.to_i
          month = params[:month]&.to_i

          return render_error("invalid parameters") if year.nil? || month.nil? || month < 1 || month > 12

          begin
            start_epoch = Time.utc(year, month, 1).to_i
            end_epoch = month == 12 ? Time.utc(year + 1, 1, 1).to_i : Time.utc(year, month + 1, 1).to_i
          rescue Date::Error
            return render_error("invalid date")
          end

          # One point per (UTC day, x pixel, y pixel, hidden): the earliest heartbeat.
          pixels = ->(y_column, condition) {
            <<~SQL
              (SELECT time, lineno, cursorpos, hidden
               FROM quantized_heartbeats
               WHERE #{condition}
               ORDER BY time ASC, id ASC
               LIMIT 1 BY day_start, qx, #{y_column ? "#{y_column}, " : ""}hidden)
            SQL
          }
          quantized_query = <<~SQL
            #{HeartbeatExclusion::INCLUDE_HIDDEN_COMMENT}
            WITH base_heartbeats AS (
                SELECT id, time, lineno, cursorpos,
                       toStartOfDay(toDateTime(toInt64(floor(time)), 'UTC')) AS day_start,
                       #{HeartbeatExclusion.hidden_sql} AS hidden
                FROM heartbeats
                WHERE user_id = #{Integer(user.id)}
                  AND deleted_at IS NULL
                  AND time >= #{Integer(start_epoch)} AND time <= #{Integer(end_epoch)}
                LIMIT 1000000
            ),
            daily_stats AS (
                SELECT *,
                       greatest(1, coalesce(max(lineno) OVER (PARTITION BY day_start), 1)) AS max_lineno,
                       greatest(1, coalesce(max(cursorpos) OVER (PARTITION BY day_start), 1)) AS max_cursorpos
                FROM base_heartbeats
            ),
            quantized_heartbeats AS (
                SELECT *,
                       round(2 + ((time - toUnixTimestamp(day_start)) / 86400) * 396) AS qx,
                       round(2 + (1 - lineno / max_lineno) * 96) AS qy_lineno,
                       round(2 + (1 - cursorpos / max_cursorpos) * 96) AS qy_cursorpos
                FROM daily_stats
            )
            SELECT time, lineno, cursorpos, hidden FROM (
              #{pixels.call('qy_lineno', 'lineno IS NOT NULL')}
              UNION DISTINCT
              #{pixels.call('qy_cursorpos', 'cursorpos IS NOT NULL')}
              UNION DISTINCT
              #{pixels.call(nil, 'lineno IS NULL AND cursorpos IS NULL')}
            )
            ORDER BY time ASC, hidden ASC
          SQL

          quantized_result = Heartbeat.connection.select_all(quantized_query).to_a
          daily_totals = Heartbeat.with_excluded.where(user_id: user.id)
            .daily_durations(user_timezone: "UTC", start_date: Time.at(start_epoch), end_date: Time.at(end_epoch)).to_h

          points_by_day = quantized_result.each_with_object({}) do |row, hash|
            day = Time.at(row["time"]).to_date
            (hash[day] ||= []) << { time: row["time"], lineno: row["lineno"], cursorpos: row["cursorpos"], hidden: row["hidden"] }
          end

          days = (start_epoch...end_epoch).step(86400).map do |epoch|
            day = Time.at(epoch).to_date
            { date_timestamp_s: epoch, total_seconds: daily_totals[day] || 0, points: points_by_day[day] || [] }
          end

          render json: { days: days }
        end

        def alt_candidates
          lookback_days = (params[:lookback_days] || 30).to_i.clamp(1, 365)
          cutoff = lookback_days.days.ago.to_i

          combos = <<~SQL
            SELECT user_id, machine, ip_address,
                   min(time) AS first_seen, max(time) AS last_seen,
                   toBool(min(#{HeartbeatExclusion.hidden_sql})) AS hidden
            FROM heartbeats
            WHERE machine IS NOT NULL
              AND ip_address IS NOT NULL
              AND deleted_at IS NULL
              AND time >= #{Integer(cutoff)}
            GROUP BY user_id, machine, ip_address
          SQL

          result = Heartbeat.connection.select_all(<<~SQL)
            #{HeartbeatExclusion::INCLUDE_HIDDEN_COMMENT}
            WITH combos AS (#{combos})
            SELECT
                r1.user_id AS user_a_id,
                r2.user_id AS user_b_id,
                r1.machine AS machine,
                r1.ip_address AS ip_address,
                r1.first_seen AS user_a_first_seen_on_combo,
                r1.last_seen AS user_a_last_seen_on_combo,
                r2.first_seen AS user_b_first_seen_on_combo,
                r2.last_seen AS user_b_last_seen_on_combo,
                r1.hidden AS user_a_hidden,
                r2.hidden AS user_b_hidden
            FROM combos AS r1
            INNER JOIN combos AS r2 ON r1.machine = r2.machine AND r1.ip_address = r2.ip_address
            WHERE r1.user_id < r2.user_id
            LIMIT 5000
          SQL

          render json: { candidates: result.to_a }
        end


        def active_users
          since_ts = params[:since].to_i
          return render_error("invalid since parameter") if since_ts < 0

          since_ts = [ since_ts, 90.days.ago.to_i ].max
          render json: { user_ids: Heartbeat.with_excluded.where("time >= ?", since_ts).distinct.limit(50_000).pluck(:user_id) }
        end

        def audit_logs_counts
          user_ids_param = params[:user_ids]
          return render_error("user_ids array required") if user_ids_param.blank? || !user_ids_param.is_a?(Array)

          user_ids = user_ids_param.take(1000)
          return render_error("no valid user_ids provided") if user_ids.empty?

          query = "SELECT user_id, COUNT(*) AS cnt FROM trust_level_audit_logs WHERE user_id IN (?) GROUP BY user_id"
          result = ActiveRecord::Base.connection.execute(ActiveRecord::Base.sanitize_sql([ query, user_ids ]))

          counts = result.each_with_object({}) { |row, h| h[row["user_id"].to_s] = row["cnt"] }
          user_ids.each { |id| counts[id.to_s] ||= 0 }

          render json: { counts: counts }
        end

        def heartbeats_by_user_agent_segment
          segment = params[:segment].to_s.strip
          return render_error("segment parameter required") if segment.blank?
          return render_error("segment must be at least 3 characters") if segment.length < 3

          limit = (params[:limit] || 1000).to_i.clamp(1, 5_000)
          offset = (params[:offset] || 0).to_i.clamp(0, Float::INFINITY)
          user_id = params[:user_id].presence

          escaped = segment.gsub(/[\\%_]/) { |c| "\\#{c}" }
          query = Heartbeat.with_excluded.where("user_agent ILIKE ?", "%#{escaped}%")
          query = query.where(user_id: user_id) if user_id
          query = apply_time_range(query) or return

          if ActiveModel::Type::Boolean.new.cast(params[:count_only])
            return render json: { segment: segment, total_count: query.limit(nil).count }
          end

          heartbeats = query.with_hidden_flag.order(time: :desc).limit(limit + 1).offset(offset).to_a
          has_more = heartbeats.size > limit
          heartbeats = heartbeats.first(limit)

          render json: {
            segment: segment,
            limit: limit,
            offset: offset,
            heartbeats: heartbeats.map { |hb|
              {
                id: hb.id,
                user_id: hb.user_id,
                time: hb.time,
                project: hb.project,
                language: hb.language,
                entity: hb.entity,
                branch: hb.branch,
                category: hb.category,
                editor: hb.editor,
                machine: hb.machine,
                operating_system: hb.operating_system,
                user_agent: hb.user_agent,
                ip_address: hb.ip_address,
                is_write: hb.is_write,
                lineno: hb.lineno,
                cursorpos: hb.cursorpos,
                lines: hb.lines,
                source_type: hb.source_type,
                hidden: hb.hidden
              }
            },
            has_more: has_more
          }
        end

        def banned_users
          limit = [ params.fetch(:limit, 200).to_i, 1000 ].min
          offset = [ params.fetch(:offset, 0).to_i, 0 ].max

          banned = User.where(trust_level: User.trust_levels[:red])
            .left_joins(:email_addresses)
            .select("users.id, users.username, MIN(email_addresses.email) AS email")
            .group("users.id, users.username").order("users.id").limit(limit).offset(offset)

          render json: { banned_users: banned.map { |u| { id: u.id, username: u.username, email: u.email || "no email" } } }
        end
      end
    end
  end
end
