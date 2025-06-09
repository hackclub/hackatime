# frozen_string_literal: true

Doorkeeper.configure do
  base_controller "ApplicationController"

  resource_owner_authenticator do
    current_user || redirect_to(minimal_login_path(continue: request.fullpath))
  end

  admin_authenticator do
    if current_user
      head :forbidden unless current_user.admin?
    else
      redirect_to sign_in_url
    end
  end

  access_token_expires_in 16.years

  reuse_access_token
end
