module Api
  module Admin
    module V1
      module UserUtilities
        extend ActiveSupport::Concern
        include DateParsing

        HEARTBEAT_RESPONSE_COLUMNS = %i[id time lineno cursorpos is_write project language entity branch category editor machine user_agent ip_address lines source_type].freeze

        HEARTBEAT_FIELD_COLUMNS = {
          "projects" => "project",
          "languages" => "language",
          "entities" => "entity",
          "branches" => "branch",
          "categories" => "category",
          "editors" => "editor",
          "machines" => "machine",
          "user_agents" => "user_agent",
          "ips" => "ip_address"
        }.freeze

        included do
          before_action :can_write!, only: [ :user_convict ]
        end

        def get_user_by_email
          return render_error("bro dont have a email") if params[:email].blank?
          email_record = EmailAddress.find_by(email: params[:email])
          return render_error("email not found", status: :not_found) unless email_record
          render json: { user_id: email_record.user_id }
        end

        def search_users_fuzzy
          return render_error("bro dont have a query") if params[:query].blank?

          users = User.fuzzy_ranked_search(params[:query], limit: 10).includes(:email_addresses)
          lower_query = params[:query].to_s.strip.downcase

          render json: {
            users: users.filter_map { |user|
              email = best_matching_email(user, lower_query)
              next unless email # preserve historical INNER JOIN behavior (only users with an email)
              {
                id: user.id,
                username: user.username,
                slack_username: user.slack_username,
                github_username: user.github_username,
                slack_avatar_url: user.slack_avatar_url,
                github_avatar_url: user.github_avatar_url,
                email: email,
                rank_score: user.rank_score
              }
            }
          }
        end

        def get_users_by_ip
          return render_error("bro dont got the ip") if params[:ip].blank?

          result = Heartbeat.where(ip_address: params[:ip]).select(:ip_address, :user_id, :machine, :user_agent).distinct
          render json: {
            users: result.map { |u|
              {
                user_id: u.user_id,
                ip_address: u.ip_address,
                machine: u.machine,
                user_agent: u.user_agent
              }
            }
          }
        end

        def get_users_by_machine
          return render_error("bro dont got the machine") if params[:machine].blank?

          result = Heartbeat.where(machine: params[:machine]).select(:user_id, :machine).distinct
          render json: { users: result.map { |u| { user_id: u.user_id, machine: u.machine } } }
        end

        def user_info
          user = find_user_by_id
          return unless user

          valid = user.heartbeats.where("CASE WHEN time > 1000000000000 THEN time / 1000 ELSE time END BETWEEN ? AND ?", Time.utc(2000, 1, 1).to_i, Time.utc(2100, 1, 1).to_i)

          lht = valid.maximum(:time)
          lht /= 1000 if lht && lht > 1000000000000

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
            range = parse_default_time_range or return
            start_time = Time.at(range.begin).utc
            end_time = Time.at(range.end).utc
          else
            date = parse_date_param_default
            return unless date
            start_time = date.beginning_of_day.utc
            end_time = date.end_of_day.utc
          end

          heartbeats = user.heartbeats.where(time: start_time.to_i..end_time.to_i).order(:time)

          render json: {
            user_id: user.id,
            username: user.display_name,
            start_date: start_time.to_date.iso8601,
            end_date: end_time.to_date.iso8601,
            timezone: user.timezone,
            heartbeats: heartbeats.map { |hb|
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
                ip_address: hb.ip_address
              }
            },
            total_heartbeats: heartbeats.count,
            total_duration: heartbeats.duration_seconds || 0
          }
        end

        def user_projects
          user = find_user_by_id
          return unless user

          base_heartbeats = user.heartbeats.where.not(project: nil)

          if params[:start_date].present? || params[:end_date].present?
            range = parse_default_time_range or return
            base_heartbeats = base_heartbeats.where(time: range)
          end

          project_stats = base_heartbeats
            .select(:project, "COUNT(*) as heartbeat_count", "MIN(time) as first_heartbeat",
                    "MAX(time) as last_heartbeat",
                    "ARRAY_AGG(DISTINCT language) FILTER (WHERE language IS NOT NULL) as languages")
            .group(:project).order(Arel.sql("COUNT(*) DESC"))

          durations = base_heartbeats.group(:project).duration_seconds
          repo_mappings = user.project_repo_mappings
            .where(project_name: project_stats.map(&:project)).index_by(&:project_name)

          project_data = project_stats.map do |stat|
            m = repo_mappings[stat.project]
            {
              name: stat.project,
              total_heartbeats: stat.heartbeat_count,
              total_duration: durations[stat.project] || 0,
              first_heartbeat: stat.first_heartbeat,
              last_heartbeat: stat.last_heartbeat,
              languages: stat.languages || [],
              repo: m&.repo_url,
              repo_mapping_id: m&.id,
              archived: m&.archived? || false
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

          return render_error("you cant punish a mortal and not justify your actions") if reason.blank?
          return render_error("read the docs you idiot") unless User.trust_levels.key?(trust_level)
          return render_error("no perms lmaooo", status: :forbidden) unless current_user.can_change_trust_of?(user, trust_level)

          success = user.set_trust(trust_level, changed_by_user: current_user, reason: reason, notes: notes)

          return render_error("no perms lmaooo") unless success

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
        end

        def trust_logs
          user = find_user_by_id
          return unless user

          logs = TrustLevelAuditLog.for_user(user).recent.limit(25)
          render json: {
            trust_logs: logs.map { |log|
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
            }
          }
        end

        def user_info_batch
          return render_error("ids parameter required") if params[:ids].blank?

          user_ids = params[:ids].to_s.split(",").map(&:strip).map(&:to_i).uniq.take(2000)
          return render_error("no valid ids provided") if user_ids.empty?

          users = User.includes(:email_addresses).where(id: user_ids)
          render json: {
            users: users.as_json(
              only: %i[id username slack_uid slack_username github_username timezone country_code trust_level slack_avatar_url github_avatar_url],
              methods: %i[display_name avatar_url]
            )
          }
        end

        def user_heartbeats
          user = find_user_by_id
          return unless user

          limit = (params[:limit] || 1000).to_i.clamp(1, 5_000)
          offset = (params[:offset] || 0).to_i.clamp(0, Float::INFINITY)

          query = user.heartbeats
          query = apply_time_range(query) or return
          %i[project language entity editor machine].each do |f|
            query = query.where(f => params[f]) if params[f].present?
          end

          total_count = query.count
          source_types = Heartbeat.source_types.invert
          heartbeats = query.order(time: :asc).limit(limit).offset(offset).pluck(*HEARTBEAT_RESPONSE_COLUMNS).map do |id, time, lineno, cursorpos, is_write, project, language, entity, branch, category, editor, machine, user_agent, ip_address, lines, source_type|
            {
              id: id,
              time: time,
              lineno: lineno || 0,
              cursorpos: cursorpos || 0,
              is_write: is_write,
              project: project,
              language: language,
              entity: entity,
              branch: branch,
              category: category,
              editor: editor,
              machine: machine,
              user_agent: user_agent,
              ip_address: ip_address,
              lines: lines,
              source_type: source_types[source_type] || source_type
            }
          end

          render json: {
            user_id: user.id,
            heartbeats: heartbeats,
            total_count: total_count,
            has_more: (offset + limit) < total_count
          }
        end

        def user_heartbeat_values
          user = find_user_by_id
          return unless user

          field = params[:field]
          column_name = HEARTBEAT_FIELD_COLUMNS[field]
          return render_error("invalid field") unless column_name

          limit = (params[:limit] || 5000).to_i.clamp(1, 5000)

          query = user.heartbeats
          query = apply_time_range(query) or return

          quoted_column = Heartbeat.connection.quote_column_name(column_name)
          values = query.where.not(column_name => nil).distinct
                        .order(Arel.sql("#{quoted_column} ASC"))
                        .limit(limit).pluck(column_name).reject(&:empty?)

          render json: { user_id: user.id, field: field, values: values, count: values.count }
        end

        private

        # Pick the email that best matches the query so the response reflects
        # the address the rank score came from (mirrors the per-email scoring
        # tiers in UserFuzzySearch). Falls back to the first email if none
        # match; returns nil if the user has no emails.
        def best_matching_email(user, lower_query)
          emails = user.email_addresses.filter_map(&:email)
          return nil if emails.empty?

          emails.max_by do |email|
            e = email.downcase
            if e == lower_query then 3
            elsif e.start_with?(lower_query) then 2
            elsif e.include?(lower_query) then 1
            else 0
            end
          end
        end

        def can_write!
          render_forbidden("no perms lmaooo") unless current_user.admin_level.in?(AuthHelpers::ADMIN_LEVELS)
        end

        def find_user_by_id
          user_id = params[:id] || params[:user_id]
          return render_error("who?") if user_id.blank?
          User.find(user_id)
        rescue ActiveRecord::RecordNotFound
          render_not_found_json("user not found")
        end
      end
    end
  end
end
