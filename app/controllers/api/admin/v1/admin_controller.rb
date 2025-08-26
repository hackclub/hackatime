module Api
  module Admin
    module V1
      class AdminController < Api::Admin::V1::ApplicationController
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

        def get_users_by_ip
          user_ip = params[:ip]

          if user_ip.blank?
            render json: { error: "bro dont got the ip" }, status: :unprocessable_entity
            return nil
          end

          result = Heartbeat.where([ "ip_address = '%s'", user_ip ]).select(:ip_address, :user_id, :machine, :user_agent).distinct

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

          result = Heartbeat.where([ "machine = '%s'", user_machine ]).select(:ip_address, :user_id, :machine, :user_agent).distinct

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

          date = parse_date_param
          return unless date

          start_time = date.beginning_of_day.utc
          end_time = date.end_of_day.utc

          heartbeats = user.heartbeats
                          .where(time: start_time..end_time)
                          .order(:time)

          render json: {
            user_id: user.id,
            username: user.username,
            date: date.iso8601,
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

          projects = user.heartbeats
                        .select(:project, "COUNT(*) as heartbeat_count")
                        .where.not(project: nil)
                        .group(:project)
                        .order(Arel.sql("COUNT(*) DESC"))

          project_data = projects.map do |heartbeat|
            project_name = heartbeat.project
            project_heartbeats = user.heartbeats.where(project: project_name)

            repo_mapping = user.project_repo_mappings.find_by(project_name: project_name)

            {
              name: project_name,
              total_heartbeats: project_heartbeats.count,
              total_duration: project_heartbeats.duration_seconds || 0,
              first_heartbeat: project_heartbeats.minimum(:time),
              last_heartbeat: project_heartbeats.maximum(:time),
              languages: project_heartbeats.distinct.pluck(:language).compact,
              repo: repo_mapping&.repo_url,
              repo_mapping_id: repo_mapping&.id
            }
          end

          render json: {
            user_id: user.id,
            username: user.username,
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
                username: user.username,
                trust_level: user.trust_level,
                updated_at: user.updated_at
              },
              audit_log: {
                changed_by: current_user.username,
                reason: reason,
                notes: notes,
                timestamp: Time.current
              }
            }
          else
            render json: { error: "no perms lmaooo" }, status: :unprocessable_entity
          end
        end

        def execute
          query = params[:query]

          if query.blank?
            return render json: { error: "whatcha doin'?" }, status: :unprocessable_entity
          end

          not_cool = %w[INSERT UPDATE DELETE DROP CREATE ALTER TRUNCATE EXEC EXECUTE]
          if not_cool.any? { |keyword| query.upcase.include?(keyword) }
            return render json: { error: "no perms lmaooo" }, status: :forbidden
          end

          unless query.strip.upcase.start_with?("SELECT")
            return render json: { error: "no perms lmaooo" }, status: :forbidden
          end

          cool = %w[created_at deleted_at]
          if query.upcase.match?(/\b(#{not_cool.join('|')})\b/) && !query.upcase.match?(/\b(#{cool.join('|')})\b/)
            return render json: { error: "no perms lmaooo" }, status: :forbidden
          end

          begin
            limited_query = query.strip
            unless limited_query.upcase.include?("LIMIT")
              limited_query += " LIMIT 1000"
            end

            sanitized_query = ActiveRecord::Base.sanitize_sql(limited_query)
            result = ActiveRecord::Base.connection.execute(sanitized_query)

            columns = result.fields
            rows = result.to_a.map { |row| columns.zip(row).to_h }

            render json: {
              success: true,
              query: sanitized_query,
              columns: columns,
              rows: rows,
              row_count: rows.count,
              executed_by: current_user.username,
              executed_at: Time.current
            }
          rescue => e
            Rails.logger.error "execute failed: #{e.message}"
            render json: {
              error: "failed #{e.message}"
            }, status: :unprocessable_entity
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

        private

        def find_user_by_id
          user_id = params[:id]

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
      end
    end
  end
end
