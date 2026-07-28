# frozen_string_literal: true

Doorkeeper.configure do
  base_controller "InertiaController"
  application_class "OauthApplication"

  default_scopes "profile"
  optional_scopes "read", "admin"
  enforce_configured_scopes

  resource_owner_authenticator do
    if respond_to?(:current_user, true)
      user = send(:current_user)
      client_id = request.params[:client_id]

      if user
        user
      elsif client_id.present? && OauthApplication.find_by(uid: client_id)&.redirect_to_hca_login?
        redirect_to(hca_auth_path(continue: request.fullpath))
      else
        redirect_to(signin_path(continue: request.fullpath))
      end
    end
  end

  admin_authenticator do
    current_user || redirect_to(signin_path(continue: request.fullpath))
  end

  enable_application_owner confirmation: false

  access_token_expires_in 16.years

  reuse_access_token

  # Allow public clients (desktop/mobile apps) without client secrets
  allow_blank_redirect_uri
  skip_client_authentication_for_password_grant

  # Enable PKCE for public clients
  force_ssl_in_redirect_uri false
end
