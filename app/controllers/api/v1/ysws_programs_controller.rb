module Api
  module V1
    class YswsProgramsController < ApplicationController
      before_action :authenticate_legacy_stats_api_key!, only: [ :claim ]

      def index = render(json: Heartbeat.ysws_programs.keys)

      def claim
        validate_params
        return if performed?

        heartbeats = find_heartbeats
        conflicting = heartbeats.where.not(ysws_program: [ nil, :nothing ])

        if conflicting.any?
          return render json: {
            error: "Some heartbeats are already claimed",
            conflicts: conflicting.pluck(:id, :ysws_program)
          }, status: :conflict
        end

        heartbeats.update_all(ysws_program: params[:program_id])
        render json: { message: "Successfully claimed #{heartbeats.count} heartbeats", claimed_count: heartbeats.count }
      end

      private

      def validate_params
        missing = %i[start_time end_time user_id program_id].select { |p| params[p].blank? }
        return render_bad_request("Missing required parameters: #{missing.join(', ')}") if missing.any?
        render_bad_request("Invalid program_id value") unless Heartbeat.ysws_programs.value?(params[:program_id].to_i)
      end

      def find_heartbeats
        user = User.find_by(id: params[:user_id]) || User.find_by(slack_uid: params[:user_id])
        return Heartbeat.none unless user.present?

        scope = Heartbeat.where(
          user_id: user.id,
          time: Time.parse(params[:start_time]).to_f..Time.parse(params[:end_time]).to_f
        )
        scope = scope.where(project: params[:project]) if params[:project].present?
        scope
      end
    end
  end
end
