module Api
  module V1
    module Authenticated
      class StreakController < ApplicationController
        skip_before_action :doorkeeper_authorize!
        before_action -> { doorkeeper_authorize! :read }, prepend: true

        def show
          render json: {
            streak_days: current_user.streak_days
          }
        end
      end
    end
  end
end
