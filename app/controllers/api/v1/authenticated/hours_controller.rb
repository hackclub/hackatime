module Api
  module V1
    module Authenticated
      class HoursController < ApplicationController
        def index
          start_date = params[:start_date]&.to_date || 7.days.ago.to_date
          end_date = params[:end_date]&.to_date || Date.current

          total_seconds = StatsClient.duration(
            user_id: current_user.id,
            start_time: start_date.beginning_of_day.to_f,
            end_time: end_date.end_of_day.to_f
          )["total_seconds"]

          render json: {
            start_date: start_date,
            end_date: end_date,
            total_seconds: total_seconds
          }
        end
      end
    end
  end
end
