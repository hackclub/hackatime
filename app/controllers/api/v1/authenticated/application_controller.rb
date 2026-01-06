module Api
  module V1
    module Authenticated
      class ApplicationController < ActionController::API
        include Doorkeeper::Rails::Helpers
        before_action :doorkeeper_authorize!
        before_action :ensure_no_ban

        private

        def current_user
          @current_user ||= User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
        end

        def ensure_no_ban
          if current_user&.trust_level == "red"
            render json: { error: "Unauthorized" }, status: :unauthorized
          end
        end
      end
    end
  end
end
