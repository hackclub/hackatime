module Api
  module V1
    module Authenticated
      class MeController < ApplicationController
        def index
          return render json: {
            emails: current_user.email_addresses&.map(&:email)|| [],
            slack_id: current_user.slack_uid
          }
        end
      end
    end
  end
end