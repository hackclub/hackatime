module Api
  module V1
    module Authenticated
      class MeController < ApplicationController
        skip_before_action :ensure_no_ban, only: :index

        def index
          exposed_level = current_user.trust_level
          app = doorkeeper_token&.application
          unless app&.verified? && app&.confidential?
            exposed_level = "blue" if exposed_level == "yellow"
          end

          render json: {
            id: current_user.id,
            emails: current_user.email_addresses&.map(&:email)|| [],
            slack_id: current_user.slack_uid,
            github_username: current_user.github_username,
            trust_factor: {
              trust_level: exposed_level,
              trust_value: User.trust_levels[exposed_level]
            }
          }
        end
      end
    end
  end
end
