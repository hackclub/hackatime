module Api
  module Admin
    module V1
      class AdminApiKeysController < Api::Admin::V1::ApplicationController
        before_action :set_admin_api_key, only: [ :show, :destroy ]

        def index
          api_keys = AdminApiKey.includes(:user).active.order(created_at: :desc)

          render json: {
            admin_api_keys: api_keys.map { |key| admin_api_key_json(key) }
          }
        end

        def show
          render json: admin_api_key_json(@admin_api_key)
        end

        def create
          admin_api_key = current_user.admin_api_keys.build(name: params[:name])

          if admin_api_key.save
            render json: {
              success: true,
              message: "Admin API key created successfully",
              admin_api_key: {
                id: admin_api_key.id,
                name: admin_api_key.name,
                token: admin_api_key.token,
                created_at: admin_api_key.created_at
              }
            }, status: :created
          else
            render json: {
              error: "Failed to create admin API key",
              errors: admin_api_key.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        def destroy
          @admin_api_key.revoke!
          render json: {
            success: true,
            message: "Admin API key has been revoked"
          }
        end

        private

        def set_admin_api_key
          @admin_api_key = AdminApiKey.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Admin API key not found" }, status: :not_found
        end

        def admin_api_key_json(key)
          {
            id: key.id,
            name: key.name,
            token_preview: "#{key.token[0..10]}...",
            user: {
              id: key.user.id,
              username: key.user.username,
              display_name: key.user.display_name,
              admin_level: key.user.admin_level
            },
            created_at: key.created_at,
            revoked_at: key.revoked_at,
            active: key.active?
          }
        end
      end
    end
  end
end
