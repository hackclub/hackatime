module Api
  module Admin
    module V1
      class LeaderboardShadowbansController < Api::Admin::V1::ApplicationController
        before_action :require_shadowban_admin!

        def index
          render json: {
            leaderboard_shadowbans: shadowbanned_users.map { |user| user_json(user, shadowbanned_by: user.leaderboard_shadowbanned_by) }
          }
        end

        def search_users
          query_term = params[:query].to_s.strip
          return render json: { users: [] } if query_term.blank?

          users = User.fuzzy_ranked_search(query_term, limit: 20).includes(:email_addresses, leaderboard_shadowbanned_by: :email_addresses)
          render json: { users: users.map { |user| user_json(user, shadowbanned_by: user.leaderboard_shadowbanned_by) } }
        end

        def create
          user = find_user
          return unless user

          PaperTrail.request(whodunnit: current_user.id) do
            unless user.set_leaderboard_shadowban(
              banned: true,
              changed_by_user: current_user,
              reason: params[:reason]
            )
              return render_shadowban_failure(user)
            end
          end

          render json: {
            success: true,
            message: "#{user.display_name} is now hidden from leaderboards.",
            user: user_json(user, shadowbanned_by: user.leaderboard_shadowbanned_by)
          }, status: :created
        end

        def destroy
          user = find_user
          return unless user

          PaperTrail.request(whodunnit: current_user.id) do
            return render_shadowban_failure(user) unless user.set_leaderboard_shadowban(banned: false, changed_by_user: current_user)
          end

          render json: {
            success: true,
            message: "#{user.display_name} is visible on leaderboards again.",
            user: user_json(user)
          }
        end

        private

        def require_shadowban_admin!
          render_forbidden("You are not authorized to manage leaderboard shadowbans.") unless current_user&.can_leaderboard_shadowban_users?
        end

        def shadowbanned_users
          User.where(leaderboard_shadowbanned: true)
            .includes(:email_addresses, leaderboard_shadowbanned_by: :email_addresses)
            .order(updated_at: :desc)
        end

        def find_user
          User.includes(:email_addresses, leaderboard_shadowbanned_by: :email_addresses).find_by(id: params[:user_id]).tap do |user|
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

        def user_json(user, shadowbanned_by: nil)
          {
            id: user.id,
            display_name: user.display_name,
            avatar_url: user.avatar_url,
            created_at: user.created_at&.iso8601,
            username: user.username,
            email: user.email_addresses.first&.email,
            leaderboard_shadowbanned: user.leaderboard_shadowbanned?,
            leaderboard_shadowban_reason: user.leaderboard_shadowban_reason,
            shadowbanned_by: shadowbanned_by_json(shadowbanned_by),
            updated_at: user.updated_at&.iso8601
          }
        end

        def shadowbanned_by_json(user)
          return nil unless user

          {
            id: user.id,
            display_name: user.display_name,
            username: user.username,
            email: user.email_addresses.first&.email
          }
        end
      end
    end
  end
end
