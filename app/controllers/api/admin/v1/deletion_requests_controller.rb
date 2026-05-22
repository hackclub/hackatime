module Api
  module Admin
    module V1
      class DeletionRequestsController < Api::Admin::V1::ApplicationController
        before_action :require_superadmin
        before_action :set_deletion_request, only: [ :show, :approve, :reject ]

        def index
          render json: {
            pending: DeletionRequest.pending.includes(:user).order(requested_at: :asc).map { |dr| deletion_request_json(dr) },
            approved: DeletionRequest.approved.includes(:user, :admin_approved_by).order(scheduled_deletion_at: :asc).map { |dr| deletion_request_json(dr) },
            completed: DeletionRequest.completed.includes(:user, :admin_approved_by).order(completed_at: :desc).limit(25).map { |dr| deletion_request_json(dr) }
          }
        end

        def show
          render json: deletion_request_json(@deletion_request)
        end

        def approve
          @deletion_request.approve!(current_user)
          render json: {
            success: true,
            message: "Deletion request approved. Scheduled for #{@deletion_request.scheduled_deletion_at.strftime('%B %d, %Y')}",
            deletion_request: deletion_request_json(@deletion_request)
          }
        end

        def reject
          @deletion_request.cancel!
          render json: {
            success: true,
            message: "Deletion request rejected",
            deletion_request: deletion_request_json(@deletion_request)
          }
        end

        private

        def set_deletion_request
          @deletion_request = DeletionRequest.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render_not_found_json("Deletion request not found")
        end

        def user_brief(u)
          u && { id: u.id, username: u.username, display_name: u.display_name }
        end

        def deletion_request_json(dr)
          {
            id: dr.id,
            user_id: dr.user_id,
            user: user_brief(dr.user),
            status: dr.status,
            requested_at: dr.requested_at,
            scheduled_deletion_at: dr.scheduled_deletion_at,
            completed_at: dr.completed_at,
            admin_approved_by: user_brief(dr.admin_approved_by),
            created_at: dr.created_at,
            updated_at: dr.updated_at
          }
        end
      end
    end
  end
end
