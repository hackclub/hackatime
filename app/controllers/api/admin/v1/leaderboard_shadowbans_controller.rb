module Api
  module Admin
    module V1
      class LeaderboardShadowbansController < Api::Admin::V1::ApplicationController
        before_action :require_shadowban_admin!

        def index
          render json: {
            leaderboard_shadowbans: shadowbanned_users.map { |user| LeaderboardShadowbanSerializer.call(user) }
          }
        end

        def search_users
          query_term = params[:query].to_s.strip
          return render json: { users: [] } if query_term.blank?

          users = User.fuzzy_ranked_search(query_term, limit: 20).includes(LeaderboardShadowbanSerializer::PRELOADS)
          render json: { users: users.map { |user| LeaderboardShadowbanSerializer.call(user) } }
        end

        def create
          user = find_user
          return unless user

          if user.set_leaderboard_shadowban(banned: true, changed_by_user: current_user, reason: params[:reason], expires_at: params[:leaderboard_shadowban_expires_at])
            render json: {
              success: true,
              message: "#{user.display_name} is now hidden from leaderboards.",
              user: LeaderboardShadowbanSerializer.call(user)
            }, status: :created
          else
            render_shadowban_failure(user)
          end
        end

        def destroy
          user = find_user
          return unless user

          if user.set_leaderboard_shadowban(banned: false, changed_by_user: current_user)
            render json: {
              success: true,
              message: "#{user.display_name} is visible on leaderboards again.",
              user: LeaderboardShadowbanSerializer.call(user)
            }
          else
            render_shadowban_failure(user)
          end
        end

        private

        def require_shadowban_admin!
          render_forbidden("You are not authorized to manage leaderboard shadowbans.") unless current_user&.can_leaderboard_shadowban_users?
        end

        def shadowbanned_users
          User.leaderboard_shadowbanned
            .includes(LeaderboardShadowbanSerializer::PRELOADS)
            .order(updated_at: :desc)
        end

        def find_user
          User.includes(LeaderboardShadowbanSerializer::PRELOADS).find_by(id: params[:user_id]).tap do |user|
            render_not_found_json("User not found") unless user
          end
        end

        def render_shadowban_failure(user)
          if user.errors.any?
            render json: {
              error: "Could not update leaderboard shadowban.",
              errors: user.errors.full_messages
            }, status: :unprocessable_entity
          else
            render_forbidden("You are not authorized to manage leaderboard shadowbans for that user.")
          end
        end
      end
    end
  end
end
