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
          render json: { error: "Unauthorized" }, status: :unauthorized if current_user&.trust_level == "red"
        end
      end
    end
  end
end
