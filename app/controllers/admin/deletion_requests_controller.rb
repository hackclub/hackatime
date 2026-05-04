class Admin::DeletionRequestsController < Admin::BaseController
  self.authorization_record = ->(c) { c.instance_variable_get(:@deletion_request) || DeletionRequest }

  # Must run before the inherited `authorize_admin_action!` so the
  # lambda above sees the loaded `@deletion_request`.
  prepend_before_action :set_deletion_request, only: [ :show, :approve, :reject ]

  def index
    @pending = DeletionRequest.pending.includes(:user).order(requested_at: :asc)
    @approved = DeletionRequest.approved.includes(:user, :admin_approved_by).order(scheduled_deletion_at: :asc)
    @done = DeletionRequest.completed.includes(:user, :admin_approved_by).order(completed_at: :desc).limit(25)
  end

  def show
  end

  def approve
    @deletion_request.approve!(current_user)
    redirect_to admin_deletion_requests_path, notice: "they gonna go kerblam on #{@deletion_request.scheduled_deletion_at.strftime('%B %d, %Y')}."
  end

  def reject
    @deletion_request.cancel!
    redirect_to admin_deletion_requests_path, notice: "ratioed + stay mad"
  end

  private

  def set_deletion_request
    @deletion_request = DeletionRequest.find(params[:id])
  end
end
