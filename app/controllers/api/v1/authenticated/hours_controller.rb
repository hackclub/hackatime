module Api
  module V1
    module Authenticated
      class HoursController < ApplicationController
        def index
          start_date = params[:start_date]&.to_date || 7.days.ago.to_date
          end_date = params[:end_date]&.to_date || Date.current

          total_seconds = current_user.heartbeats
                                      .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
                                      .duration_seconds

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
