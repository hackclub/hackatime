module Api
  module V1
    module Authenticated
      class ApplicationController < ActionController::API
        include Doorkeeper::Rails::Helpers
        before_action :doorkeeper_authorize!
        before_action :ensure_api_access_allowed

        private

        def current_user
          @current_user ||= User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
        end

        def ensure_api_access_allowed
          render json: { error: "Unauthorized" }, status: :unauthorized if current_user&.api_access_restricted?
        end

        def ensure_profile_access_allowed
          return if current_user&.authentication_allowed? && !current_user.pending_deletion?

          render json: { error: "Unauthorized" }, status: :unauthorized
        end
      end
    end
  end
end
