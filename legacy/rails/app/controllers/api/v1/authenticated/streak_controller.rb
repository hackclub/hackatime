module Api
  module V1
    module Authenticated
      class StreakController < ApplicationController
        def show
          render json: {
            streak_days: current_user.streak_days
          }
        end
      end
    end
  end
end
