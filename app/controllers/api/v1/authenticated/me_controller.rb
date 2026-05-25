module Api
  module V1
    module Authenticated
      class MeController < ApplicationController
        skip_before_action :ensure_no_ban, only: :index

        def index
          app = doorkeeper_token&.application
          exposed_level = if app&.verified? && app&.confidential?
            current_user.trust_level
          else
            current_user.public_trust_level
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
