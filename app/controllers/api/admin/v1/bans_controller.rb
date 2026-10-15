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

          poison = @user.apply_poison!(cutoff, reason: ban_params[:reason], by: current_user)

          render json: { success: true, user_id: @user.id, **poison_json(poison) }, status: :created
        rescue ArgumentError => e
          if e.message.include?("future")
            render_error("date cannot be in the future")
          else
            render_error("date is invalid")
          end
        end

        def show
          poison = @user.active_poison
          render json: { user_id: @user.id, poisoned: poison.present?, **poison_json(poison) }
        end

        def destroy
          unless @user.remove_poison!(by: current_user)
            return render json: { success: true, user_id: @user.id, poisoned_until: nil, already_unbanned: true }
          end

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

        def poison_json(poison)
          {
            poisoned_until: poison&.ends_at&.iso8601,
            poisoned_at: poison&.created_at&.iso8601,
            poison_reason: poison&.reason,
            hidden_heartbeats: poison ? poison.heartbeats.count : 0
          }
        end
      end
    end
  end
end
