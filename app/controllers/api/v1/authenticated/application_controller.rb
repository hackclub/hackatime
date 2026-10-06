module Api
  module V1
    module Authenticated
      class ApplicationController < ActionController::API
        include Doorkeeper::Rails::Helpers
        class_attribute :required_oauth_scopes, default: []

        before_action :authorize_oauth_scopes!
        before_action :ensure_api_access_allowed
        include AuthenticatedApiRateLimiting

        def self.require_oauth_scope(scope)
          self.required_oauth_scopes = [ scope ]
        end

        private

        def authorize_oauth_scopes! = doorkeeper_authorize!(*required_oauth_scopes)

        def authenticated_api_rate_limit_identity = "user:#{current_user.id}"

        def current_user
          @current_user ||= User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
        end

        def ensure_api_access_allowed
          render json: { error: "Unauthorized" }, status: :unauthorized if current_user&.api_access_restricted?
        end

        def ensure_no_pending_deletion
          render json: { error: "Unauthorized" }, status: :unauthorized if current_user&.pending_deletion?
        end
      end
    end
  end
end
