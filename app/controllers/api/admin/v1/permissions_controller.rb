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

          if user.set_admin_level(new_level)
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
      end
    end
  end
end
