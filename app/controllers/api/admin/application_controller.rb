module Api
  module Admin
    class ApplicationController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate_admin_api_key!

      private

      def authenticate_admin_api_key!
        authenticate_or_request_with_http_token do |token, options|
          @admin_api_key = AdminApiKey.active.find_by(token: token)

          if @admin_api_key
            @current_user = @admin_api_key.user

            unless @current_user.admin_level.in?([ "admin", "superadmin", "viewer" ])
              @admin_api_key.revoke!
              render json: { error: "lmao no perms" }, status: :unauthorized
              false
            else
              true
            end
          else
            render json: { error: "lmao no perms" }, status: :unauthorized
          end
        end
      end

      def current_user
        @current_user
      end

      def current_admin_api_key
        @admin_api_key
      end

      def render_unauthorized
        render json: { error: "lmao no perms" }, status: :unauthorized
      end

      def render_forbidden
        render json: { error: "lmao no perms" }, status: :forbidden
      end
    end
  end
end
