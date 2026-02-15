module Api
  module Admin
    module V1
      class TimelineController < Api::Admin::V1::ApplicationController
        MAX_TIMELINE_USERS = 20

        def show
          date = params[:date] ? Date.parse(params[:date]) : Time.current.to_date

          raw_user_ids = params[:user_ids].present? ? params[:user_ids].split(",").map(&:to_i).uniq : []

          if params[:slack_uids].present?
            slack_uids = params[:slack_uids].split(",").first(MAX_TIMELINE_USERS)
            users_from_slack_uids = User.where(slack_uid: slack_uids)
            raw_user_ids += users_from_slack_uids.pluck(:id)
          end

          raw_user_ids = raw_user_ids.first(MAX_TIMELINE_USERS)

          selected_user_ids = [ current_user.id ] + raw_user_ids
          selected_user_ids.uniq!

          service = TimelineService.new(date: date, selected_user_ids: selected_user_ids)
          timeline_data = service.timeline_data

          users_with_timeline_data = timeline_data.map do |entry|
            user = entry[:user]
            {
              user: {
                id: user.id,
                username: user.username,
                display_name: user.display_name,
                slack_username: user.slack_username,
                github_username: user.github_username,
                timezone: user.timezone,
                avatar_url: user.avatar_url
              },
              spans: entry[:spans],
              total_coded_time: entry[:total_coded_time]
            }
          end

          render json: {
            date: date.iso8601,
            next_date: (date + 1.day).iso8601,
            prev_date: (date - 1.day).iso8601,
            users: users_with_timeline_data,
            commit_markers: service.commit_markers
          }
        rescue Date::Error
          render json: { error: "Invalid date format" }, status: :unprocessable_entity
        end

        def search_users
          query_term = params[:query].to_s.downcase

          if query_term.blank?
            return render json: { error: "Query parameter is required" }, status: :unprocessable_entity
          end

          user_id_match = nil
          if query_term.match?(/^\d+$/)
            user_id = query_term.to_i
            user_id_match = User.where(id: user_id).first
          end

          if user_id_match
            results = [ {
              id: user_id_match.id,
              display_name: user_id_match.display_name,
              avatar_url: user_id_match.avatar_url
            } ]
          else
            users = User.where("LOWER(username) LIKE :query OR LOWER(slack_username) LIKE :query OR CAST(id AS TEXT) LIKE :query OR EXISTS (SELECT 1 FROM email_addresses WHERE email_addresses.user_id = users.id AND LOWER(email_addresses.email) LIKE :query)", query: "%#{query_term}%")
                        .order(Arel.sql("CASE WHEN LOWER(username) = #{ActiveRecord::Base.connection.quote(query_term)} THEN 0 ELSE 1 END, username ASC"))
                        .limit(20)
                        .select(:id, :username, :slack_username, :github_username, :slack_avatar_url, :github_avatar_url)

            results = users.map do |user|
              {
                id: user.id,
                display_name: user.display_name,
                avatar_url: user.avatar_url
              }
            end
          end

          render json: { users: results }
        end

        def leaderboard_users
          period = params[:period]
          limit = 25

          leaderboard_period_type = (period == "last_7_days") ? :last_7_days : :daily
          start_date = Date.current

          leaderboard = Leaderboard.where.not(finished_generating_at: nil)
                                   .find_by(start_date: start_date, period_type: leaderboard_period_type, deleted_at: nil)

          user_ids_from_leaderboard = leaderboard ? leaderboard.entries.order(total_seconds: :desc).limit(limit).pluck(:user_id) : []

          all_ids_to_fetch = user_ids_from_leaderboard.dup
          all_ids_to_fetch.unshift(current_user.id).uniq!

          users_data = User.where(id: all_ids_to_fetch)
                           .select(:id, :username, :slack_username, :github_username, :slack_avatar_url, :github_avatar_url)
                           .index_by(&:id)

          final_user_objects = []
          if admin_data = users_data[current_user.id]
            final_user_objects << { id: admin_data.id, display_name: admin_data.display_name, avatar_url: admin_data.avatar_url }
          end

          user_ids_from_leaderboard.each do |uid|
            break if final_user_objects.size >= limit
            next if uid == current_user.id

            if user_data = users_data[uid]
              final_user_objects << { id: user_data.id, display_name: user_data.display_name, avatar_url: user_data.avatar_url }
            end
          end

          render json: { users: final_user_objects }
        end
      end
    end
  end
end
