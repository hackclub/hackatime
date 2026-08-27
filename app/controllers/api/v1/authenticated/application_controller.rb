module Api
  module V1
    module Authenticated
      class ApplicationController < ActionController::API
        include Doorkeeper::Rails::Helpers
        before_action :doorkeeper_authorize!
        before_action :ensure_api_access_allowed
        include AuthenticatedApiRateLimiting

        def self.require_oauth_scope(scope)
          skip_before_action :doorkeeper_authorize!
          before_action -> { doorkeeper_authorize! scope }, prepend: true
        end

        private

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
