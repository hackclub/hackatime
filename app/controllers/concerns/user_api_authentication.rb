# frozen_string_literal: true

module UserApiAuthentication
  extend ActiveSupport::Concern

  private

  def api_user_from_credentials(oauth_scopes: nil, api_key_sources: [ :bearer ], allow_restricted: false)
    scheme, authorization_token = authorization_credentials
    api_key_token = api_key_token_from(
      scheme:,
      authorization_token:,
      sources: api_key_sources
    )

    normalized_api_key_token = normalize_api_token(api_key_token)
    user = ApiKey.find_by(token: normalized_api_key_token)&.user if normalized_api_key_token.present?
    user ||= oauth_user_from_token(authorization_token, oauth_scopes) if oauth_scopes && bearer_scheme?(scheme)
    return if user&.api_access_restricted? && !allow_restricted

    user
  end

  def authorization_credentials
    request.headers["Authorization"].to_s.split(/\s+/, 2)
  end

  def api_key_token_from(scheme:, authorization_token:, sources:)
    return authorization_token if sources.include?(:bearer) && bearer_scheme?(scheme)

    if sources.include?(:basic) && scheme&.casecmp?("Basic")
      return Base64.strict_decode64(authorization_token.to_s)
    end

    params[:api_key] if sources.include?(:query) && params[:api_key].present?
  rescue ArgumentError
    nil
  end

  def oauth_user_from_token(raw_token, required_scopes)
    normalized_token = normalize_api_token(raw_token)
    return unless normalized_token.present?

    token = Doorkeeper::AccessToken.by_token(normalized_token)
    User.find_by(id: token.resource_owner_id) if token&.acceptable?(required_scopes)
  end

  def normalize_api_token(token)
    value = token.to_s
    return if value.encoding == Encoding::UTF_8 && !value.valid_encoding?

    value = value.encode(Encoding::UTF_8)
    value if value.valid_encoding?
  rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
    nil
  end

  def bearer_scheme?(scheme) = scheme&.casecmp?("Bearer")
end
