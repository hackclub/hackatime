module Api
  module Admin
    class ApplicationController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods
      include RenderHelpers

      before_action :authenticate_admin_api_key!

      private

      def authenticate_admin_api_key!
        authenticate_or_request_with_http_token do |token, _options|
          @admin_api_key = AdminApiKey.active.includes(:user).find_by(token: token)
          next false unless @admin_api_key

          @current_user = @admin_api_key.user
          if @current_user.admin_level.in?(%w[admin superadmin viewer ultraadmin])
            true
          else
            @admin_api_key.revoke!
            false
          end
        end
      end

      def current_user
        @current_user
      end

      def current_admin_api_key
        @admin_api_key
      end

      def require_superadmin
        unless current_user&.admin_level_superadmin? || current_user&.admin_level_ultraadmin?
          render_unauthorized("lmao no perms")
        end
      end
    end
  end
end
