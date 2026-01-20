# frozen_string_literal: true

Doorkeeper.configure do
  base_controller "ApplicationController"
  application_class "OauthApplication"

  default_scopes "profile"
  optional_scopes "read"
  enforce_configured_scopes

  resource_owner_authenticator do
    current_user || redirect_to(minimal_login_path(continue: request.fullpath))
  end

  admin_authenticator do
    current_user || redirect_to(minimal_login_path(continue: request.fullpath))
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
