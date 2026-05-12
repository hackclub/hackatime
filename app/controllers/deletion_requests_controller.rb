class DeletionRequestsController < InertiaController
  layout "inertia", only: [ :show ]

  before_action :require_login
  before_action :check_can_request, only: [ :create ]

  def show
    @deletion_request = current_user.active_deletion_request
    return redirect_to root_path, alert: "no request" unless @deletion_request

    render inertia: "DeletionRequests/Show", props: deletion_request_props
  end

  def create
    @deletion_request = DeletionRequest.create_for_user!(current_user, **deletion_request_params)
    redirect_to deletion_path
  rescue ActiveRecord::RecordInvalid => e
    report_error(e, message: "Deletion request creation failed")
    redirect_to my_settings_path
  end

  def cancel
    @deletion_request = current_user.active_deletion_request
    if @deletion_request&.can_be_cancelled?
      @deletion_request.cancel!
      redirect_to my_settings_path, notice: "Your deletion request has been cancelled!"
    else
      redirect_to deletion_path
    end
  end

  private

  def inertia_layout_props
    super.merge(hide_sidebar: true)
  end

  def require_login
    redirect_to root_path, alert: "who?" unless current_user
  end

  def check_can_request
    unless current_user.can_request_deletion?
      redirect_to my_settings_path, alert: "You can't request deletion right now."
    end
  end

  def deletion_request_params
    params.fetch(:deletion_request, {}).permit(:reason, :reason_details).to_h.symbolize_keys
  end

  def deletion_request_props
    {
      deletion_request: {
        status: @deletion_request.status,
        status_label: @deletion_request.status.humanize,
        requested_at: @deletion_request.requested_at.strftime("%B %d, %Y at %I:%M %p"),
        scheduled_deletion_at: @deletion_request.scheduled_deletion_at&.strftime("%B %d, %Y"),
        days_until_deletion: @deletion_request.days_until_deletion,
        can_be_cancelled: @deletion_request.can_be_cancelled?
      }
    }
  end
end
