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

    establish_local_session(email_address.user, label: email_address.email)
  end

  def log_me_in_user
    user = User.find_by(id: params[:id])
    return render plain: "No local user has that ID.\n", status: :not_found unless user

    establish_local_session(user, label: "user ##{user.id}")
  end

  def log_me_out
    reset_session
    redirect_to dev_path, notice: "Signed out."
  end

  private

  def establish_local_session(user, label:)
    return render plain: "That local user cannot sign in.\n", status: :forbidden unless user.authentication_allowed?

    reset_session
    session[:user_id] = user.id
    session[:authentication_version] = user.authentication_version
    session[:auth_provider] = "development"
    session[:authenticated_at] = Time.current.to_i
    redirect_to root_path, notice: "Signed in as #{label}."
  end

  def ensure_local_environment
    raise ActionController::RoutingError, "Not Found" unless Rails.env.local?
  end
end
