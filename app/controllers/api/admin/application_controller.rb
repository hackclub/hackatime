module Api
  module Admin
    class ApplicationController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods
      include Pundit::Authorization

      before_action :authenticate_admin_api_key!

      rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

      private

      def authenticate_admin_api_key!
        authenticate_or_request_with_http_token do |token, options|
          admin_api_key = AdminApiKey.active.find { |key| ActiveSupport::SecurityUtils.secure_compare(key.token, token) }
          @admin_api_key = admin_api_key

          if @admin_api_key
            @current_user = @admin_api_key.user

            # Any non-default tier (admin/superadmin/viewer/ultraadmin) may
            # use admin API keys. The fine-grained gate happens via Pundit.
            if AdminPolicy.new(@current_user, :admin).access?
              true
            else
              @admin_api_key.revoke!
              false
            end
          else
            false
          end
        end
      end

      def current_user
        @current_user
      end

      def pundit_user
        current_user
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

      # Pundit semantically maps to 403 Forbidden, but we return 401 here
      # to preserve back-compat with existing API clients that branch on
      # the legacy status code from `require_superadmin`. Update the
      # contract before changing this to `:forbidden`.
      def user_not_authorized(_exception)
        render json: { error: "lmao no perms" }, status: :unauthorized
      end
    end
  end
end
