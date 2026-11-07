module Api
  module V1
    module Authenticated
      class HoursController < ApplicationController
        include RenderHelpers
        include DateParsing

        require_oauth_scope :read

        def index
          date_range = parse_date_range(
            start_value: params[:start_date],
            end_value: params[:end_date],
            start_default: 7.days.ago.to_date,
            end_default: Date.current
          ) { |value| value.to_s.to_date }
          return unless date_range

          start_date = date_range.begin
          end_date = date_range.end

          total_seconds = current_user.heartbeats
                                      .where(time: start_date.beginning_of_day.to_i..end_date.end_of_day.to_i)
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
