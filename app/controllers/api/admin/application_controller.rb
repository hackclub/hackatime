module Api
  module Admin
    class ApplicationController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods
      include AdminApiKeyAuthentication
      include RenderHelpers

      ADMIN_API_LEVELS = AdminApiKeyAuthentication::ADMIN_API_LEVELS

      before_action :authenticate_admin!
      before_action :set_paper_trail_whodunnit
      around_action :allow_poisoned_heartbeats

      private

      def allow_poisoned_heartbeats(&block)
        return yield unless ActiveModel::Type::Boolean.new.cast(params[:include_poison])

        Heartbeat.including_poison(&block)
      end

      def authenticate_admin!
        authenticate_or_request_with_http_token do |token, _|
          auth_admin_api_key(token) || auth_oauth_admin(token)
        end
      end
      alias_method :authenticate_admin_api_key!, :authenticate_admin!

      def auth_oauth_admin(token)
        t = Doorkeeper::AccessToken.by_token(token)
        return false unless t&.acceptable?([ OauthApplication::ADMIN_SCOPE ])

        application = t.application
        return false unless application&.admin_scope? && application.confidential? && application.verified?

        u = User.find_by(id: t.resource_owner_id)
        return false unless admin_api_user?(u)

        @oauth_token, @current_user = t, u
        true
      end

      def current_user = @current_user
      def current_admin_api_key = @admin_api_key
      def current_oauth_token = @oauth_token
      def set_paper_trail_whodunnit = PaperTrail.request.whodunnit = current_user&.id

      def require_superadmin
        render_unauthorized("lmao no perms") unless current_user&.admin_level_superadmin? || current_user&.admin_level_ultraadmin?
      end
    end
  end
end
