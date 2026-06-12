module Api
  module Admin
    module V1
      class PermissionsController < Api::Admin::V1::ApplicationController
        include AdminLevelChangeMessages

        before_action :require_superadmin

        def index
          users = User.where.not(admin_level: :default).order(admin_level: :asc, username: :asc)
          users = users.where(id: User.search_identity(params[:search]).pluck(:id)) if params[:search].present?
          users = users.includes(:email_addresses)

          render json: {
            users: users.map do |user|
              {
                id: user.id,
                username: user.username,
                display_name: user.display_name,
                slack_username: user.slack_username,
                github_username: user.github_username,
                admin_level: user.admin_level,
                email_addresses: user.email_addresses.map(&:email),
                created_at: user.created_at,
                updated_at: user.updated_at
              }
            end
          }
        end

        def update
          user = User.find(params[:id])
          previous_level = user.admin_level
          new_level = params[:admin_level]

          return render_error("Invalid admin level") unless User.admin_levels.key?(new_level)
          return render_error(admin_level_change_denial_message(user, new_level), status: :forbidden) unless current_user.can_change_admin_level_of?(user, new_level)

          if user.set_admin_level(new_level, changed_by_user: current_user)
            Rails.logger.info "Admin level changed: User #{user.id} (#{user.display_name}) from #{previous_level} to #{new_level} by #{current_user.display_name}"
            render json: {
              success: true,
              message: "#{user.display_name}'s admin level updated from #{previous_level} to #{new_level}",
              user: {
                id: user.id,
                username: user.username,
                display_name: user.display_name,
                admin_level: user.admin_level,
                previous_admin_level: previous_level,
                updated_at: user.updated_at
              }
            }
          else
            render_error("Failed to update admin level")
          end
        rescue ActiveRecord::RecordNotFound
          render_not_found_json("User not found")
        end
      end
    end
  end
end
