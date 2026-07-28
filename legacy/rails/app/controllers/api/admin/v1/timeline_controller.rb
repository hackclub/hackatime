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
            raw_user_ids += User.where(slack_uid: slack_uids).pluck(:id)
          end
          raw_user_ids = raw_user_ids.first(MAX_TIMELINE_USERS)

          selected_user_ids = ([ current_user.id ] + raw_user_ids).uniq
          service = TimelineService.new(date: date, selected_user_ids: selected_user_ids)

          users_with_timeline_data = service.timeline_data.map do |entry|
            u = entry[:user]
            {
              user: {
                id: u.id,
                username: u.username,
                display_name: u.display_name,
                slack_username: u.slack_username,
                github_username: u.github_username,
                timezone: u.timezone,
                avatar_url: u.avatar_url
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
          render_error("Invalid date format")
        end

        def search_users
          query_term = params[:query].to_s
          return render_error("Query parameter is required") if query_term.blank?

          users = User.fuzzy_ranked_search(query_term, limit: 20)
          render json: { users: users.map { |u| user_summary(u) } }
        end

        def leaderboard_users
          period = params[:period]
          limit = 25

          leaderboard = Leaderboard.where.not(finished_generating_at: nil)
                                   .find_by(start_date: Date.current,
                                            period_type: (period == "last_7_days") ? :last_7_days : :daily,
                                            deleted_at: nil)

          user_ids_from_leaderboard = leaderboard ? leaderboard.entries.order(total_seconds: :desc).limit(limit).pluck(:user_id) : []
          all_ids_to_fetch = ([ current_user.id ] + user_ids_from_leaderboard).uniq

          users_data = User.where(id: all_ids_to_fetch)
                           .select(:id, :username, :slack_username, :github_username, :slack_avatar_url, :github_avatar_url, :display_name_override)
                           .preload(:email_addresses)
                           .index_by(&:id)

          final_user_objects = []
          final_user_objects << user_summary(users_data[current_user.id]) if users_data[current_user.id]

          user_ids_from_leaderboard.each do |uid|
            break if final_user_objects.size >= limit
            next if uid == current_user.id
            final_user_objects << user_summary(users_data[uid]) if users_data[uid]
          end

          render json: { users: final_user_objects }
        end

        private

        def user_summary(user)
          { id: user.id, display_name: user.display_name, avatar_url: user.avatar_url }
        end
      end
    end
  end
end
