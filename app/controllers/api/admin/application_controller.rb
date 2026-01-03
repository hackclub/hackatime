module Api
  module Admin
    class ApplicationController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate_admin_api_key!

      private

      def authenticate_admin_api_key!
        token = request.headers["Authorization"]&.split(" ")&.last
        
        unless token
          render json: { error: "lmao no perms" }, status: :unauthorized
          return
        end

        @admin_api_key = AdminApiKey.active.find_by(token: token)

        unless @admin_api_key
          render json: { error: "lmao no perms" }, status: :unauthorized
          return
        end

        @current_user = @admin_api_key.user

        unless @current_user.admin_level.in?([ "admin", "superadmin", "viewer" ])
          @admin_api_key.revoke!
          render json: { error: "lmao no perms" }, status: :unauthorized
          return
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
