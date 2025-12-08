class DeletionRequestsController < ApplicationController
  before_action :require_login
  before_action :check_can_request, only: [ :create ]

  def show
    @deletion_request = current_user.active_deletion_request
    redirect_to root_path, alert: "no request" unless @deletion_request
  end

  def create
    @deletion_request = DeletionRequest.create_for_user!(current_user)
    redirect_to deletion_path
  rescue ActiveRecord::RecordInvalid => e
    Sentry.capture_exception(e)
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

  def require_login
    redirect_to root_path, alert: "who?" unless current_user
  end

  def check_can_request
    unless current_user.can_request_deletion?
      redirect_to my_settings_path, alert: "You can't request deletion right now."
    end
  end
end
