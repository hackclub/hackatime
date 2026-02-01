module Api
  module V1
    class YswsProgramsController < ApplicationController
      before_action :ensure_authenticated!, only: [ :claim ]

      def index
        render json: Heartbeat.ysws_programs.keys
      end

      def claim
        validate_params

        heartbeats = find_heartbeats
        conflicting_heartbeats = heartbeats.where.not(ysws_program: [ nil, :nothing ])

        if conflicting_heartbeats.any?
          render json: {
            error: "Some heartbeats are already claimed",
            conflicts: conflicting_heartbeats.pluck(:id, :ysws_program)
          }, status: :conflict
          return
        end

        heartbeats.update_all(ysws_program: params[:program_id])

        render json: {
          message: "Successfully claimed #{heartbeats.count} heartbeats",
          claimed_count: heartbeats.count
        }
      end

      private

      def ensure_authenticated!
        token = request.headers["Authorization"]&.split(" ")&.last
        token ||= params[:api_key]

        render json: { error: "Unauthorized" }, status: :unauthorized unless token == ENV["STATS_API_KEY"]
      end

      def validate_params
        required_params = [ :start_time, :end_time, :user_id, :program_id ]
        missing_params = required_params.select { |param| params[param].blank? }

        if missing_params.any?
          render json: { error: "Missing required parameters: #{missing_params.join(', ')}" }, status: :bad_request
        end

        unless Heartbeat.ysws_programs.value?(params[:program_id].to_i)
          render json: { error: "Invalid program_id value" }, status: :bad_request
        end
      end

      def find_heartbeats
        user = User.where(id: params[:user_id]).first
        user ||= User.where(slack_uid: params[:user_id]).first

        return Heartbeat.none unless user.present?

        scope = Heartbeat.where(
          user_id: user.id,
          time: Time.parse(params[:start_time]).to_f..Time.parse(params[:end_time]).to_f
        )

        if params[:project].present?
          scope = scope.where(project: params[:project])
        end

        scope
      end
    end
  end
end
