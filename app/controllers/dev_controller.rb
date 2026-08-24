class DevController < ApplicationController
  before_action :ensure_local_environment

  def index
    render plain: <<~TEXT
      Development endpoints:
      GET /__dev/log-me-in/<email>
      GET /__dev/log-me-out
    TEXT
  end

  def log_me_in
    email_address = EmailAddress.find_by(email: params[:email].downcase)
    return render plain: "No local user has that email address.\n", status: :not_found unless email_address

    reset_session
    session[:user_id] = email_address.user_id
    return render plain: "Signed in" if Rails.env.test?

    redirect_to root_path, notice: "Signed in as #{email_address.email}."
  end

  def log_me_out
    reset_session
    redirect_to dev_path, notice: "Signed out."
  end

  private

  def ensure_local_environment
    raise ActionController::RoutingError, "Not Found" unless Rails.env.local?
  end
end
