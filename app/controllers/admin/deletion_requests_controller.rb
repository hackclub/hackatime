class Admin::DeletionRequestsController < Admin::BaseController
  before_action :set_deletion_request, only: [ :show, :approve, :reject ]
  before_action -> { require_admin_level!(:superadmin) }
  before_action -> { require_admin_level!(:ultraadmin) }, only: [ :new, :create ]

  def index
    @pending = DeletionRequest.pending.includes(:user).order(requested_at: :asc)
    @approved = DeletionRequest.approved.includes(:user, :admin_approved_by).order(scheduled_deletion_at: :asc)
    @done = DeletionRequest.completed.includes(:user, :admin_approved_by).order(completed_at: :desc).limit(25)
  end

  def show
  end

  def new
    @deletion_request = DeletionRequest.new
  end

  def create
    user = User.find_by(id: deletion_request_params[:user_id])
    return redirect_to new_admin_deletion_request_path, alert: "user not found" unless user

    if user.active_deletion_request.present?
      return redirect_to new_admin_deletion_request_path, alert: "#{user.display_name} already has an active deletion request"
    end

    instant = deletion_request_params[:instant] == "1"
    audit = "#{instant ? "speedy " : ""}deletion manually requested by admin #{current_user.username}"

    deletion_request = DeletionRequest.create_for_user!(user, reason: "admin", reason_details: audit)

    if instant
      deletion_request.approve!(current_user)
      deletion_request.update!(scheduled_deletion_at: Time.current)
      ProcessAccountDeletionsJob.perform_later
      redirect_to admin_deletion_requests_path, notice: "deletion queued for #{user.display_name}"
    else
      redirect_to admin_deletion_requests_path, notice: "deletion request created for #{user.display_name}"
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to new_admin_deletion_request_path, alert: e.message
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

  def deletion_request_params = params.fetch(:deletion_request, {}).permit(:user_id, :instant)
end
