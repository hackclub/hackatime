# frozen_string_literal: true

require Rails.root.join("lib/omniauth/strategies/hca")

hca_redirect_uri = ENV["HCA_REDIRECT_URI"].presence || begin
  public_url = ENV["PUBLIC_URL"].presence || "http://localhost:3000"
  URI.join("#{public_url.delete_suffix('/')}/", "auth/hca/callback").to_s
end

OmniAuth.config.logger = Rails.logger
OmniAuth.config.allowed_request_methods = [ :post ]

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :hca,
    issuer: HCAService.host,
    discovery: true,
    scope: %i[openid email slack_id],
    response_type: :code,
    uid_field: "sub",
    send_state: true,
    require_state: true,
    send_nonce: true,
    pkce: true,
    client_signing_alg: :RS256,
    client_auth_method: :basic,
    client_options: {
      identifier: ENV["HCA_CLIENT_ID"],
      secret: ENV["HCA_CLIENT_SECRET"],
      redirect_uri: hca_redirect_uri
    }
end
