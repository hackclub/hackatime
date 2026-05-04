module Api
  module V1
    module Authenticated
      class ApplicationController < ActionController::API
        include Doorkeeper::Rails::Helpers
        include Pundit::Authorization

        before_action :doorkeeper_authorize!
        before_action :ensure_no_ban

        private

        def current_user
          @current_user ||= User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
        end

        def pundit_user
          current_user
        end

        # Red-trust ("convicted") users are soft-banned from the
        # OAuth-authenticated API. Centralized in UserPolicy.
        def ensure_no_ban
          unless UserPolicy.new(current_user, current_user).use_authenticated_api?
            render json: { error: "Unauthorized" }, status: :unauthorized
          end
        end
      end
    end
  end
end
