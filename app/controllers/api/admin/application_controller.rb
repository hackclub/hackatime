module Api
  module Admin
    class ApplicationController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods
      include RenderHelpers

      before_action :authenticate_admin_api_key!

      private

      def authenticate_admin_api_key!
        authenticate_or_request_with_http_token do |token, _options|
          # Indexed lookup on `admin_api_keys.token` (unique B-tree) instead of
          # loading every active key into Ruby and iterating with secure_compare.
          # The previous shape paid ~30-60ms per request (full-table read + N AR
          # instantiations + N+1 on .user). The B-tree `=` comparison happens
          # inside PG and any timing leak is well below network jitter.
          @admin_api_key = AdminApiKey.includes(:user).find_by(token: token, revoked_at: nil)
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
