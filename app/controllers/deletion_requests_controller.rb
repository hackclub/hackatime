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
    return begin_hca_step_up if current_user.hca_id.present?

    create_deletion_request(deletion_request_params)
  end

  def hca_callback
    pending_request = session.delete(:pending_deletion_request)

    unless valid_hca_state?(pending_request&.dig("state"))
      report_message("HCA deletion step-up state was invalid")
      return redirect_to(my_settings_path, alert: "Hack Club Auth verification failed. Please try again.")
    end

    if params[:error].present?
      report_message("HCA deletion step-up error: #{params[:error]}") unless params[:error] == "access_denied"
      return redirect_to(my_settings_path, alert: "Hack Club Auth verification was cancelled.")
    end

    unless pending_request["user_id"] == current_user.id &&
        pending_request["hca_id"] == current_user.hca_id && params[:code].present?
      report_message("HCA deletion step-up context was invalid")
      return redirect_to(my_settings_path, alert: "Hack Club Auth verification failed. Please try again.")
    end

    redirect_uri = hca_deletion_callback_url
    hca_id = User.hca_id_from_token(params[:code], redirect_uri)
    unless hca_id.present? && hca_id == pending_request["hca_id"]
      report_message("HCA deletion step-up identity did not match User ##{current_user.id}")
      return redirect_to(my_settings_path, alert: "Please verify with the Hack Club Account linked to Hackatime.")
    end

    unless current_user.can_request_deletion?
      return redirect_to(my_settings_path, alert: "You can't request deletion right now.")
    end

    create_deletion_request(pending_request.fetch("attributes").symbolize_keys)
  rescue HTTP::Error, JSON::ParserError => e
    report_error(e, message: "HCA deletion step-up failed")
    redirect_to my_settings_path, alert: "Hack Club Auth verification failed. Please try again."
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
    super.merge(hide_sidebar: true, hide_footer: true)
  end

  def require_login
    redirect_to root_path, alert: "who?" unless current_user
  end

  def check_can_request
    unless current_user.can_request_deletion?
      redirect_to my_settings_path, alert: "You can't request deletion right now."
    end
  end

  def begin_hca_step_up
    attributes = deletion_request_params
    if attributes[:reason].to_s.length > DeletionRequest::MAX_REASON_LENGTH ||
        attributes[:reason_details].to_s.length > DeletionRequest::MAX_REASON_DETAILS_LENGTH
      return redirect_to(my_settings_path, alert: "Deletion details are too long.")
    end

    state = SecureRandom.hex(24)
    session[:pending_deletion_request] = {
      "state" => state,
      "user_id" => current_user.id,
      "hca_id" => current_user.hca_id,
      "attributes" => attributes.stringify_keys
    }

    redirect_to User.hca_authorize_url(
      hca_deletion_callback_url,
      state:,
      prompt: "login",
      scope: "openid email slack_id verification_status"
    ), host: HCAService.host, allow_other_host: HCAService.host
  end

  def valid_hca_state?(expected_state)
    expected_state.present? && params[:state].present? &&
      ActiveSupport::SecurityUtils.secure_compare(params[:state].to_s, expected_state.to_s)
  end

  def create_deletion_request(attributes)
    @deletion_request = DeletionRequest.create_for_user!(current_user, **attributes)
    redirect_to deletion_path
  rescue ActiveRecord::RecordInvalid => e
    report_error(e, message: "Deletion request creation failed")
    redirect_to my_settings_path
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
