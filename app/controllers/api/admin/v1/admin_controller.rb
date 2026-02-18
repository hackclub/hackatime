module Api
  module Admin
    module V1
      class AdminController < Api::Admin::V1::ApplicationController
        before_action :can_write!, only: [ :user_convict ]

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

        def get_user_by_email
          email = params[:email]

          if email.blank?
            render json: { error: "bro dont have a email" }, status: :unprocessable_entity
            return
          end

          email_record = EmailAddress.find_by email: email
          if email_record.nil?
            render json: { error: "email not found" }, status: :not_found
            return
          end

          render json: {
            user_id: email_record.user_id
          }
        end


        def search_users_fuzzy
          query = params[:query]
          if query.blank?
            render json: { error: "bro dont have a query" }, status: :unprocessable_entity
            return
          end

          query = ActiveRecord::Base.sanitize_sql_like(query)

          user_search_query = <<-SQL
            SELECT
              id, username, slack_username, github_username,
              slack_avatar_url, github_avatar_url, email
            FROM (
              SELECT
                users.id,
                users.username,
                users.slack_username,
                users.github_username,
                users.slack_avatar_url,
                users.github_avatar_url,
                email_addresses.email,
                (
                  CASE WHEN users.id::text = :query THEN 1000 ELSE 0 END +
                  CASE WHEN users.slack_uid = :query THEN 1000 ELSE 0 END +
                  CASE
                    WHEN users.username ILIKE :query THEN 100
                    WHEN users.username ILIKE :query || '%' THEN 50
                    WHEN users.username ILIKE '%' || :query || '%' THEN 10
                    ELSE 0
                  END +
                  CASE
                    WHEN users.github_username ILIKE :query THEN 100
                    WHEN users.github_username ILIKE :query || '%' THEN 50
                    WHEN users.github_username ILIKE '%' || :query || '%' THEN 10
                    ELSE 0
                  END +
                  CASE
                    WHEN users.slack_username ILIKE :query THEN 100
                    WHEN users.slack_username ILIKE :query || '%' THEN 50
                    WHEN users.slack_username ILIKE '%' || :query || '%' THEN 10
                    ELSE 0
                  END +
                  CASE
                    WHEN email_addresses.email ILIKE :query THEN 100
                    WHEN email_addresses.email ILIKE :query || '%' THEN 50
                    WHEN email_addresses.email ILIKE '%' || :query || '%' THEN 10
                    ELSE 0
                  END
                ) AS rank_score
              FROM
                users
                INNER JOIN email_addresses ON users.id=email_addresses.user_id
              WHERE
                users.id::text = :query
                OR users.slack_uid = :query
                OR users.username ILIKE '%' || :query || '%'
                OR users.github_username ILIKE '%' || :query || '%'
                OR users.slack_username ILIKE '%' || :query || '%'
                OR email_addresses.email ILIKE '%' || :query || '%'
            ) AS ranked_users
            WHERE
              rank_score > 0
            ORDER BY
              rank_score DESC,
              username ASC
            LIMIT 10
          SQL

          sanitized_query = ActiveRecord::Base.sanitize_sql([ user_search_query, query: query ])
          result = ActiveRecord::Base.connection.execute(sanitized_query)

          render json: {
            users: result.to_a
          }
        end


        def get_users_by_ip
          user_ip = params[:ip]

          if user_ip.blank?
            render json: { error: "bro dont got the ip" }, status: :unprocessable_entity
            return nil
          end

          result = Heartbeat.where(ip_address: user_ip).select(:ip_address, :user_id, :machine, :user_agent).distinct

          render json: {
            users: result.map do |user| {
              user_id: user.user_id,
              ip_address: user.ip_address,
              machine: user.machine,
              user_agent: user.user_agent
            }
            end
          }
        end

        def get_users_by_machine
          user_machine = params[:machine]

          if user_machine.blank?
            render json: { error: "bro dont got the machine" }, status: :unprocessable_entity
            return nil
          end

          result = Heartbeat.where(machine: user_machine).select(:user_id, :machine).distinct

          render json: {
            users: result.map do |user| {
              user_id: user.user_id,
              machine: user.machine
            }
            end
          }
        end

        def user_info
          user = find_user_by_id
          return unless user
          valid = user.heartbeats.where("CASE WHEN time > 1000000000000 THEN time / 1000 ELSE time END BETWEEN ? AND ?", Time.utc(2000, 1, 1).to_i, Time.utc(2100, 1, 1).to_i)

          lht = valid.maximum(:time)
          if lht && lht > 1000000000000
            lht = lht / 1000
          end

          render json: {
            user: {
              id: user.id,
              username: user.username,
              display_name: user.display_name,
              slack_uid: user.slack_uid,
              slack_username: user.slack_username,
              github_username: user.github_username,
              timezone: user.timezone,
              country_code: user.country_code,
              admin_level: user.admin_level,
              trust_level: user.trust_level,
              suspected: user.trust_level == "yellow",
              banned: user.trust_level == "red",
              created_at: user.created_at,
              updated_at: user.updated_at,
              last_heartbeat_at: lht,
              email_addresses: user.email_addresses.map(&:email),
              api_keys_count: user.api_keys.count,
              stats: {
                total_heartbeats: valid.count,
                total_coding_time: valid.duration_seconds || 0,
                languages_used: valid.distinct.pluck(:language).compact.count,
                projects_worked_on: valid.distinct.pluck(:project).compact.count,
                days_active: valid.distinct.count("DATE(to_timestamp(CASE WHEN time > 1000000000000 THEN time / 1000 ELSE time END))")
              }
            }
          }
        end

        def user_stats
          user = find_user_by_id
          return unless user

          if params[:start_date].present? || params[:end_date].present?
            start_time = begin
              Date.parse(params[:start_date]).beginning_of_day.utc
            rescue
              10.years.ago.utc
            end
            end_time = begin
              Date.parse(params[:end_date]).end_of_day.utc
            rescue
              Date.current.end_of_day.utc
            end
          else
            date = parse_date_param
            return unless date

            start_time = date.beginning_of_day.utc
            end_time = date.end_of_day.utc
          end

          heartbeats = user.heartbeats
                          .where(time: start_time..end_time)
                          .order(:time)

          render json: {
            user_id: user.id,
            username: user.display_name,
            start_date: start_time.to_date.iso8601,
            end_date: end_time.to_date.iso8601,
            timezone: user.timezone,
            heartbeats: heartbeats.map do |hb|
              {
                id: hb.id,
                time: Time.at(hb.time).utc.iso8601,
                created_at: hb.created_at,
                project: hb.project,
                branch: hb.branch,
                category: hb.category,
                dependencies: hb.dependencies,
                editor: hb.editor,
                entity: hb.entity,
                language: hb.language,
                machine: hb.machine,
                operating_system: hb.operating_system,
                type: hb.type,
                user_agent: hb.user_agent,
                line_additions: hb.line_additions,
                line_deletions: hb.line_deletions,
                lineno: hb.lineno,
                lines: hb.lines,
                cursorpos: hb.cursorpos,
                project_root_count: hb.project_root_count,
                is_write: hb.is_write,
                source_type: hb.source_type,
                ysws_program: hb.ysws_program,
                ip_address: hb.ip_address
              }
            end,
            total_heartbeats: heartbeats.count,
            total_duration: heartbeats.duration_seconds || 0
          }
        end

        def user_projects
          user = find_user_by_id
          return unless user

          base_heartbeats = user.heartbeats.where.not(project: nil)

          if params[:start_date].present? || params[:end_date].present?
            start_time = begin
              Date.parse(params[:start_date]).beginning_of_day.utc.to_i
            rescue
              10.years.ago.utc.to_i
            end
            end_time = begin
              Date.parse(params[:end_date]).end_of_day.utc.to_i
            rescue
              Date.current.end_of_day.utc.to_i
            end
            base_heartbeats = base_heartbeats.where(time: start_time..end_time)
          end

          project_stats = base_heartbeats
            .select(
              :project,
              "COUNT(*) as heartbeat_count",
              "MIN(time) as first_heartbeat",
              "MAX(time) as last_heartbeat",
              "ARRAY_AGG(DISTINCT language) FILTER (WHERE language IS NOT NULL) as languages"
            )
            .group(:project)
            .order(Arel.sql("COUNT(*) DESC"))

          durations = base_heartbeats.group(:project).duration_seconds

          repo_mappings = user.project_repo_mappings
            .where(project_name: project_stats.map(&:project))
            .index_by(&:project_name)

          project_data = project_stats.map do |stat|
            repo_mapping = repo_mappings[stat.project]
            {
              name: stat.project,
              total_heartbeats: stat.heartbeat_count,
              total_duration: durations[stat.project] || 0,
              first_heartbeat: stat.first_heartbeat,
              last_heartbeat: stat.last_heartbeat,
              languages: stat.languages || [],
              repo: repo_mapping&.repo_url,
              repo_mapping_id: repo_mapping&.id,
              archived: repo_mapping&.archived? || false
            }
          end

          render json: {
            user_id: user.id,
            username: user.display_name,
            projects: project_data,
            total_projects: project_data.count
          }
        end

        def user_convict
          user = find_user_by_id
          return unless user

          trust_level = params[:trust_level]
          reason = params[:reason]
          notes = params[:notes]

          if reason.blank?
            return render json: { error: "you cant punish a mortal and not justify your actions" }, status: :unprocessable_entity
          end

          unless User.trust_levels.key?(trust_level)
            return render json: { error: "read the docs you idiot" }, status: :unprocessable_entity
          end

          if trust_level == "red" && !current_user.can_convict_users?
            return render json: { error: "no perms lmaooo" }, status: :forbidden
          end

          success = user.set_trust(
            trust_level,
            changed_by_user: current_user,
            reason: reason,
            notes: notes
          )

          if success
            render json: {
              success: true,
              message: "gotcha, updated to #{trust_level}",
              user: {
                id: user.id,
                username: user.display_name,
                trust_level: user.trust_level,
                updated_at: user.updated_at
              },
              audit_log: {
                changed_by: current_user.display_name,
                reason: reason,
                notes: notes,
                timestamp: Time.current
              }
            }
          else
            render json: { error: "no perms lmaooo" }, status: :unprocessable_entity
          end
        end

        def trust_logs
          user = find_user_by_id
          return unless user
          logs = TrustLevelAuditLog.for_user(user).recent.limit(25)
          render json: {
            trust_logs: logs.map do |log|
              {
                id: log.id,
                previous_trust_level: log.previous_trust_level,
                new_trust_level: log.new_trust_level,
                changed_by: {
                  id: log.changed_by.id,
                  username: log.changed_by.username,
                  display_name: log.changed_by.display_name,
                  admin_level: log.changed_by.admin_level
                },
                reason: log.reason,
                notes: log.notes,
                created_at: log.created_at
              }
            end
          }
        end

        def user_info_batch
          ids_param = params[:ids]

          if ids_param.blank?
            render json: { error: "ids parameter required" }, status: :unprocessable_entity
            return
          end

          user_ids = ids_param.to_s.split(",").map(&:strip).map(&:to_i).uniq.take(2000)

          if user_ids.empty?
            render json: { error: "no valid ids provided" }, status: :unprocessable_entity
            return
          end

          users = User.includes(:email_addresses).where(id: user_ids)

          render json: {
            users: users.map do |user|
              {
                id: user.id,
                username: user.username,
                display_name: user.display_name,
                slack_uid: user.slack_uid,
                slack_username: user.slack_username,
                github_username: user.github_username,
                timezone: user.timezone,
                country_code: user.country_code,
                trust_level: user.trust_level,
                avatar_url: user.avatar_url,
                slack_avatar_url: user.slack_avatar_url,
                github_avatar_url: user.github_avatar_url
              }
            end
          }
        end

        def user_heartbeats
          user = find_user_by_id
          return unless user

          start_date = params[:start_date]
          end_date = params[:end_date]
          project = params[:project]
          language = params[:language]
          entity = params[:entity]
          editor = params[:editor]
          machine = params[:machine]
          limit = (params[:limit] || 1000).to_i.clamp(1, 5_000)
          offset = (params[:offset] || 0).to_i.clamp(0, Float::INFINITY)

          query = user.heartbeats

          if start_date.present?
            start_timestamp = parse_timestamp(start_date)
            query = query.where("time >= ?", start_timestamp) if start_timestamp
          end

          if end_date.present?
            end_timestamp = parse_timestamp(end_date)
            query = query.where("time <= ?", end_timestamp) if end_timestamp
          end

          query = query.where(project: project) if project.present?
          query = query.where(language: language) if language.present?
          query = query.where(entity: entity) if entity.present?
          query = query.where(editor: editor) if editor.present?
          query = query.where(machine: machine) if machine.present?

          total_count = query.count

          heartbeats = query.order(time: :asc).limit(limit).offset(offset)

          render json: {
            user_id: user.id,
            heartbeats: heartbeats.map do |hb|
              {
                id: hb.id,
                time: hb.time,
                lineno: hb.lineno || 0,
                cursorpos: hb.cursorpos || 0,
                is_write: hb.is_write,
                project: hb.project,
                language: hb.language,
                entity: hb.entity,
                branch: hb.branch,
                category: hb.category,
                editor: hb.editor,
                machine: hb.machine,
                user_agent: hb.user_agent,
                ip_address: hb.ip_address,
                lines: hb.lines,
                source_type: hb.source_type
              }
            end,
            total_count: total_count,
            has_more: (offset + limit) < total_count
          }
        end

        def user_heartbeat_values
          user = find_user_by_id
          return unless user

          field = params[:field]
          start_date = params[:start_date]
          end_date = params[:end_date]
          limit = (params[:limit] || 5000).to_i.clamp(1, 5000)

          unless %w[projects languages entities branches categories editors machines user_agents ips].include?(field)
            render json: { error: "invalid field" }, status: :unprocessable_entity
            return
          end

          column_map = {
            "projects" => "project",
            "languages" => "language",
            "entities" => "entity",
            "branches" => "branch",
            "categories" => "category",
            "editors" => "editor",
            "machines" => "machine",
            "user_agents" => "user_agent",
            "ips" => "ip_address"
          }

          column_name = column_map[field]

          query = user.heartbeats.select(
            Arel.sql("DISTINCT COALESCE(#{Heartbeat.connection.quote_column_name(column_name)}, '') AS value")
          )

          if start_date.present?
            start_timestamp = parse_timestamp(start_date)
            query = query.where("time >= ?", start_timestamp) if start_timestamp
          end

          if end_date.present?
            end_timestamp = parse_timestamp(end_date)
            query = query.where("time <= ?", end_timestamp) if end_timestamp
          end

          values = query
                   .where.not(column_name => nil)
                   .order(Arel.sql("value ASC"))
                   .limit(limit)
                   .pluck(Arel.sql("value"))
                   .reject(&:empty?)

          render json: {
            user_id: user.id,
            field: field,
            values: values,
            count: values.count
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
                    "time",
                    lineno,
                    cursorpos,
                    date_trunc('day', to_timestamp("time")) as day_start
                FROM heartbeats
                WHERE user_id = ?
                AND "time" >= ? AND "time" <= ?
                AND (lineno IS NOT NULL OR cursorpos IS NOT NULL)
                LIMIT 1000000
            ),
            daily_stats AS (
                SELECT
                    *,
                    GREATEST(1, MAX(lineno) OVER (PARTITION BY day_start)) as max_lineno,
                    GREATEST(1, MAX(cursorpos) OVER (PARTITION BY day_start)) as max_cursorpos
                FROM base_heartbeats
            ),
            quantized_heartbeats AS (
                SELECT
                    *,
                    ROUND(2 + (("time" - extract(epoch from day_start)) / 86400) * (396)) as qx,
                    ROUND(2 + (1 - CAST(lineno AS decimal) / max_lineno) * (96)) as qy_lineno,
                    ROUND(2 + (1 - CAST(cursorpos AS decimal) / max_cursorpos) * (96)) as qy_cursorpos
                FROM daily_stats
            )
            SELECT "time", lineno, cursorpos
            FROM (
                SELECT DISTINCT ON (day_start, qx, qy_lineno) "time", lineno, cursorpos
                FROM quantized_heartbeats
                WHERE lineno IS NOT NULL
                ORDER BY day_start, qx, qy_lineno, "time" ASC
            ) AS lineno_pixels
            UNION
            SELECT "time", lineno, cursorpos
            FROM (
                SELECT DISTINCT ON (day_start, qx, qy_cursorpos) "time", lineno, cursorpos
                FROM quantized_heartbeats
                WHERE cursorpos IS NOT NULL
                ORDER BY day_start, qx, qy_cursorpos, "time" ASC
            ) AS cursorpos_pixels
            ORDER BY "time" ASC
          SQL

          daily_totals_query = <<-SQL
            WITH heartbeats_with_gaps AS (
              SELECT
                date_trunc('day', to_timestamp("time"))::date as day,
                "time" - LAG("time", 1, "time") OVER (PARTITION BY date_trunc('day', to_timestamp("time")) ORDER BY "time") as gap
              FROM heartbeats
              WHERE user_id = ? AND time >= ? AND time <= ?
            )
            SELECT
              day,
              SUM(LEAST(gap, 120)) as total_seconds
            FROM heartbeats_with_gaps
            WHERE gap IS NOT NULL
            GROUP BY day
          SQL

          quantized_result = ActiveRecord::Base.connection.execute(
            ActiveRecord::Base.sanitize_sql([ quantized_query, user.id, start_epoch, end_epoch ])
          )

          daily_totals_result = ActiveRecord::Base.connection.execute(
            ActiveRecord::Base.sanitize_sql([ daily_totals_query, user.id, start_epoch, end_epoch ])
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

        private

        def can_write!
          # blocks viewers
          unless current_user.admin_level.in?([ "admin", "superadmin" ])
            render json: { error: "no perms lmaooo" }, status: :forbidden
          end
        end

        def find_user_by_id
          user_id = params[:id] || params[:user_id]

          if user_id.blank?
            render json: { error: "who?" }, status: :unprocessable_entity
            return nil
          end

          User.find(user_id)
        rescue ActiveRecord::RecordNotFound
          render json: { error: "user not found" }, status: :not_found
          nil
        end

        def parse_date_param
          date_param = params[:date]

          if date_param.blank?
            return Date.current
          end

          Date.parse(date_param)
        rescue Date::Error
          render json: { error: "tf is that date ya dumbass" }, status: :unprocessable_entity
          nil
        end

        def parse_timestamp(date_param)
          if date_param.to_s.match?(/^\d+$/)
            timestamp = date_param.to_i
            return timestamp if timestamp.between?(0, 2147483647)
          end

          begin
            Date.parse(date_param).beginning_of_day.to_i
          rescue Date::Error
            nil
          end
        end
      end
    end
  end
end
