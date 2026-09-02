module Api
  module Admin
    module V1
      class UsersController < Api::Admin::V1::ApplicationController
        include DateParsing

        def get_user_by_email
          return render_error("bro dont have a email") if params[:email].blank?
          email_record = EmailAddress.find_by(email: params[:email])
          return render_error("email not found", status: :not_found) unless email_record
          render json: { user_id: email_record.user_id }
        end

        def search_users_fuzzy
          return render_error("bro dont have a query") if params[:query].blank?

          relation = User.fuzzy_ranked_search(params[:query], limit: 10)
          rows = User.connection.select_all(relation.to_sql).to_a

          render json: {
            users: rows.filter_map { |row|
              next unless row["has_any_email"] # gate: preserve legacy INNER JOIN behavior
              {
                id: row["id"],
                username: row["username"],
                slack_username: row["slack_username"],
                github_username: row["github_username"],
                slack_avatar_url: row["slack_avatar_url"],
                github_avatar_url: row["github_avatar_url"],
                email: row["matched_email"],
                rank_score: row["rank_score"]
              }
            }
          }
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
      end
    end
  end
end
