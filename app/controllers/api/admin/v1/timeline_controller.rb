module Api
  module Admin
    module V1
      class TimelineController < Api::Admin::V1::ApplicationController
        def show
          date = params[:date] ? Date.parse(params[:date]) : Time.current.to_date
          service = TimelineService.for_selection(
            date: date,
            current_user: current_user,
            user_ids: params[:user_ids],
            slack_uids: params[:slack_uids]
          )

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

          users = TimelineService.search_users(query_term)
          render json: { users: users.map { |u| user_summary(u) } }
        end

        def leaderboard_users
          users = TimelineService.leaderboard_users(current_user: current_user, period: params[:period])
          render json: { users: users.map { |user| user_summary(user) } }
        end

        private

        def user_summary(user)
          { id: user.id, display_name: user.display_name, avatar_url: user.avatar_url }
        end
      end
    end
  end
end
