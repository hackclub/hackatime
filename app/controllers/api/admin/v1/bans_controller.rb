module Api
  module Admin
    module V1
      class BansController < Api::Admin::V1::ApplicationController
        MAX_RAW_DATE_LENGTH = 40

        before_action :require_superadmin
        before_action :set_user

        def create
          cutoff = ban_date
          return render_error("date is required") if cutoff.blank?

          @user.apply_poison!(cutoff, reason: ban_params[:reason])

          render json: {
            success: true,
            user_id: @user.id,
            poisoned_until: @user.poisoned_until.iso8601,
            poisoned_at: @user.poisoned_at.iso8601,
            poison_reason: @user.poison_reason,
            hidden_heartbeats: hidden_heartbeat_count
          }, status: :created
        rescue ArgumentError => e
          if e.message.include?("future")
            render_error("date cannot be in the future")
          else
            render_error("date is invalid")
          end
        end

        def show
          render json: {
            user_id: @user.id,
            poisoned: @user.poisoned?,
            poisoned_until: @user.poisoned_until&.iso8601,
            poisoned_at: @user.poisoned_at&.iso8601,
            poison_reason: @user.poison_reason,
            hidden_heartbeats: hidden_heartbeat_count
          }
        end

        def destroy
          unless @user.poisoned?
            return render json: { success: true, user_id: @user.id, poisoned_until: nil, already_unbanned: true }
          end

          @user.remove_poison!

          render json: { success: true, user_id: @user.id, poisoned_until: nil }
        end

        private

        def set_user
          @user = User.lookup_by_identifier(params[:hackatime_id].to_s)
          render_not_found_json("User not found") unless @user
        end

        def ban_params = params.permit(:date, :end_date, :reason)

        def ban_date
          permitted = ban_params
          return permitted[:date] if permitted[:date].present?
          return permitted[:end_date] if permitted[:end_date].present?

          raw = request.raw_post.to_s.strip
          return if raw.blank? || raw.length > MAX_RAW_DATE_LENGTH
          raw unless raw.start_with?("{", "[")
        end

        def hidden_heartbeat_count = Heartbeat.only_poisoned.where(user_id: @user.id).count
      end
    end
  end
end
