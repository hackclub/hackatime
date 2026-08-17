class Admin::DeletionRequestsController < Admin::BaseController
  before_action :set_deletion_request, only: [ :show, :approve, :reject ]
  before_action -> { require_admin_level!(:superadmin) }
  before_action -> { require_admin_level!(:ultraadmin) }, only: [ :new, :confirm, :create ]

  def index
    @pending = DeletionRequest.pending.includes(user: :email_addresses).order(requested_at: :asc)
    @approved = DeletionRequest.approved.includes(:user, :admin_approved_by).order(scheduled_deletion_at: :asc)
    @done = DeletionRequest.completed.includes(:user, :admin_approved_by).order(completed_at: :desc).limit(25)
    render inertia: "Admin/DeletionRequests/Index", props: {
      pending: @pending.map { |request| serialize_request(request, requested_at: "#{helpers.time_ago_in_words(request.requested_at)} ago") },
      approved: @approved.map { |request| serialize_request(request, approved_at: request.admin_approved_at&.strftime("%b %d, %Y"), deletion_at: request.scheduled_deletion_at&.strftime("%b %d, %Y"), days: request.days_until_deletion) },
      done: @done.map { |request| { user_id: request.user_id, approver: request.admin_approved_by&.display_name || "N/A", completed_at: request.completed_at&.strftime("%b %d, %Y at %I:%M %p") } }
    }
  end

  def show = redirect_to(admin_deletion_requests_path)

  def new
    render inertia: "Admin/DeletionRequests/New"
  end

  def confirm
    @user = lookup_user(params[:q])
    return redirect_to new_admin_deletion_request_path, alert: "user not found" unless @user
    render inertia: "Admin/DeletionRequests/Confirm", props: { user: serialize_confirmation_user(@user) }
  end

  def create
    user = nil
    user = User.find_by(id: deletion_request_params[:user_id])
    return redirect_to new_admin_deletion_request_path, alert: "user not found" unless user

    expected_confirmation = user.username.presence || "DELETE"
    if deletion_request_params[:confirm_username] != expected_confirmation
      return redirect_to confirm_admin_deletion_requests_path(q: user.id), alert: "username didn't match"
    end

    if user.active_deletion_request.present?
      return redirect_to confirm_admin_deletion_requests_path(q: user.id), alert: "#{user.display_name} already has an active deletion request"
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
    redirect_to confirm_admin_deletion_requests_path(q: user&.id || deletion_request_params[:user_id]), alert: e.message
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

  def serialize_request(request, extra = {})
    { id: request.id, user: { display_name: request.user.display_name, avatar_url: request.user.avatar_url,
      email: request.user.email_addresses.first&.email || "N/A", trust_level: request.user.trust_level },
      approver: request.admin_approved_by&.display_name || "N/A" }.merge(extra)
  end

  def serialize_confirmation_user(user)
    { id: user.id, display_name: user.display_name, avatar_url: user.avatar_url, username: user.username,
      trust_level: user.trust_level, email: user.email_addresses.first&.email || "none",
      joined_at: user.created_at.strftime("%B %d, %Y"), active_deletion_request: user.active_deletion_request.present? }
  end

  def set_deletion_request
    @deletion_request = DeletionRequest.find(params[:id])
  end

  def lookup_user(q)
    User.lookup_by_identifier(q.to_s) || EmailAddress.find_by(email: q.to_s)&.user
  end

  def deletion_request_params = params.fetch(:deletion_request, {}).permit(:user_id, :instant, :confirm_username)
end
