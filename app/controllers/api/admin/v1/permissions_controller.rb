module Api
  module Admin
    module V1
      class PermissionsController < Api::Admin::V1::ApplicationController
        before_action :require_superadmin

        def index
          users = User.where.not(admin_level: :default)
                     .order(admin_level: :asc, username: :asc)

          if params[:search].present?
            user_ids = User.search_identity(params[:search]).pluck(:id)
            users = users.where(id: user_ids)
          end

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

          unless User.admin_levels.key?(new_level)
            return render json: { error: "Invalid admin level" }, status: :unprocessable_entity
          end

          unless current_user.can_change_admin_level_of?(user, new_level)
            return render json: { error: forbidden_reason(user, new_level) }, status: :forbidden
          end

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
            render json: { error: "Failed to update admin level" }, status: :unprocessable_entity
          end
        rescue ActiveRecord::RecordNotFound
          render json: { error: "User not found" }, status: :not_found
        end

        private

        def forbidden_reason(target_user, new_level)
          if target_user == current_user
            "You cannot change your own admin level"
          elsif new_level.to_s == "ultraadmin" && current_user.admin_level != "ultraadmin"
            "Only ultraadmins can grant the ultraadmin role"
          elsif target_user.admin_level == "ultraadmin"
            "Only ultraadmins can change an ultraadmin's role"
          else
            "You are not authorized to change this user's admin level"
          end
        end
      end
    end
  end
end
