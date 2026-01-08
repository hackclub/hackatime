module Api
  module Admin
    module V1
      class DeletionRequestsController < Api::Admin::V1::ApplicationController
        before_action :require_superadmin
        before_action :set_deletion_request, only: [ :show, :approve, :reject ]

        def index
          pending = DeletionRequest.pending.includes(:user).order(requested_at: :asc)
          approved = DeletionRequest.approved.includes(:user, :admin_approved_by).order(scheduled_deletion_at: :asc)
          done = DeletionRequest.completed.includes(:user, :admin_approved_by).order(completed_at: :desc).limit(25)

          render json: {
            pending: pending.map { |dr| deletion_request_json(dr) },
            approved: approved.map { |dr| deletion_request_json(dr) },
            completed: done.map { |dr| deletion_request_json(dr) }
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
          render json: { error: "Deletion request not found" }, status: :not_found
        end

        def deletion_request_json(dr)
          {
            id: dr.id,
            user_id: dr.user_id,
            user: dr.user ? {
              id: dr.user.id,
              username: dr.user.username,
              display_name: dr.user.display_name
            } : nil,
            status: dr.status,
            requested_at: dr.requested_at,
            scheduled_deletion_at: dr.scheduled_deletion_at,
            completed_at: dr.completed_at,
            admin_approved_by: dr.admin_approved_by ? {
              id: dr.admin_approved_by.id,
              username: dr.admin_approved_by.username,
              display_name: dr.admin_approved_by.display_name
            } : nil,
            created_at: dr.created_at,
            updated_at: dr.updated_at
          }
        end
      end
    end
  end
end
