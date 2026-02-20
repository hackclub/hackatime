module Api
  module Admin
    module V1
      module UserUtilities
        extend ActiveSupport::Concern

        included do
          before_action :can_write!, only: [ :user_convict ]
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
            start_timestamp = parse_timestamp_param(params[:start_date], field_name: "start_date", boundary: :start, default: 10.years.ago.utc.to_i)
            return if performed?

            end_timestamp = parse_timestamp_param(params[:end_date], field_name: "end_date", boundary: :end, default: Date.current.end_of_day.utc.to_i)
            return if performed?

            start_time = Time.at(start_timestamp).utc
            end_time = Time.at(end_timestamp).utc
          else
            date = parse_date_param
            return unless date

            start_time = date.beginning_of_day.utc
            end_time = date.end_of_day.utc
          end

          heartbeats = user.heartbeats
                           .where(time: start_time.to_i..end_time.to_i)
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
            start_time = parse_timestamp_param(params[:start_date], field_name: "start_date", boundary: :start, default: 10.years.ago.utc.to_i)
            return if performed?

            end_time = parse_timestamp_param(params[:end_date], field_name: "end_date", boundary: :end, default: Date.current.end_of_day.utc.to_i)
            return if performed?

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
            start_timestamp = parse_timestamp_param(start_date, field_name: "start_date", boundary: :start)
            return if performed?

            query = query.where("time >= ?", start_timestamp)
          end

          if end_date.present?
            end_timestamp = parse_timestamp_param(end_date, field_name: "end_date", boundary: :end)
            return if performed?

            query = query.where("time <= ?", end_timestamp)
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

          query = user.heartbeats

          if start_date.present?
            start_timestamp = parse_timestamp_param(start_date, field_name: "start_date", boundary: :start)
            return if performed?

            query = query.where("time >= ?", start_timestamp)
          end

          if end_date.present?
            end_timestamp = parse_timestamp_param(end_date, field_name: "end_date", boundary: :end)
            return if performed?

            query = query.where("time <= ?", end_timestamp)
          end

          quoted_column = Heartbeat.connection.quote_column_name(column_name)
          values = query
                   .where.not(column_name => nil)
                   .distinct
                   .order(Arel.sql("#{quoted_column} ASC"))
                   .limit(limit)
                   .pluck(column_name)
                   .reject(&:empty?)

          render json: {
            user_id: user.id,
            field: field,
            values: values,
            count: values.count
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
          return Date.current if date_param.blank?

          Date.parse(date_param)
        rescue Date::Error, ArgumentError
          render json: { error: "tf is that date ya dumbass" }, status: :unprocessable_entity
          nil
        end

        def parse_timestamp_param(date_param, field_name:, boundary:, default: nil)
          return default if date_param.blank?

          parsed = parse_timestamp(date_param, boundary: boundary)
          return parsed if parsed

          render json: { error: "invalid #{field_name}" }, status: :unprocessable_entity
          nil
        end

        def parse_timestamp(date_param, boundary:)
          raw_value = date_param.to_s.strip

          if raw_value.match?(/\A\d+\z/)
            timestamp = raw_value.to_i
            timestamp /= 1000 if timestamp >= 1_000_000_000_000
            return timestamp if timestamp.between?(0, 253_402_300_799)
            return nil
          end

          parsed_date = Date.parse(raw_value)
          boundary == :end ? parsed_date.end_of_day.to_i : parsed_date.beginning_of_day.to_i
        rescue Date::Error, ArgumentError
          nil
        end
      end
    end
  end
end
