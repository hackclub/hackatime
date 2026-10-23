# frozen_string_literal: true

# Rack::Attack limits API requests without credentials by IP. Requests with
# credentials on routes using this concern skip those limits and are limited
# here by who they authenticate as: a user, or an admin credential with a much
# higher allowance. Including controllers define
# authenticated_api_rate_limit_identity, which returns nil when the request
# isn't authenticated.
module AuthenticatedApiRateLimiting
  extend ActiveSupport::Concern

  USER_LIMIT = 600
  ADMIN_LIMIT = 5000
  REJECTED_CREDENTIALS_LIMIT = 300
  PERIOD = 1.minute.to_i

  FAILURE_STATUSES = [ 401, 403 ].freeze

  included do
    # Runs before authentication, so rejected credentials are limited by IP.
    prepend_around_action :limit_rejected_api_credentials, if: :authenticated_api_rate_limited?

    rate_limit to: USER_LIMIT, within: PERIOD,
      by: :authenticated_api_rate_limit_discriminator,
      with: -> { render_authenticated_api_rate_limit_exceeded(USER_LIMIT) },
      scope: "authenticated-api",
      if: -> { authenticated_api_rate_limited? && !admin_api_rate_limit? && authenticated_api_rate_limit_identity }

    rate_limit to: ADMIN_LIMIT, within: PERIOD,
      by: :authenticated_api_rate_limit_discriminator,
      with: -> { render_authenticated_api_rate_limit_exceeded(ADMIN_LIMIT) },
      scope: "admin-api",
      if: -> { authenticated_api_rate_limited? && admin_api_rate_limit? && authenticated_api_rate_limit_identity }
  end

  private

  # Override to limit only some actions. Rack::Attack's credential-limited
  # routes must match.
  def authenticated_api_rate_limited_action? = true

  def admin_api_rate_limit? = false

  def authenticated_api_rate_limited?
    request.env["rack.attack.match_type"] != :safelist && authenticated_api_rate_limited_action?
  end

  # Matches Rack::Attack.api_credentials?
  def api_credentials_presented?
    request.headers["Authorization"].present? || request.query_parameters["api_key"].present?
  end

  def limit_rejected_api_credentials
    return yield unless api_credentials_presented?

    key = "authenticated-api-failures:#{request.remote_ip}:#{authenticated_api_rate_limit_window}"
    if cache_store.read(key).to_i >= REJECTED_CREDENTIALS_LIMIT
      return render_authenticated_api_rate_limit_exceeded(REJECTED_CREDENTIALS_LIMIT)
    end

    yield
    if response.status.in?(FAILURE_STATUSES) || authenticated_api_rate_limit_identity.nil?
      cache_store.increment(key, 1, expires_in: PERIOD)
    end
  end

  def authenticated_api_rate_limit_discriminator
    "#{authenticated_api_rate_limit_identity}:#{authenticated_api_rate_limit_window}"
  end

  def authenticated_api_rate_limit_window
    window = Time.current.to_i / PERIOD
    @authenticated_api_rate_limit_reset_time = (window + 1) * PERIOD
    window
  end

  def render_authenticated_api_rate_limit_exceeded(limit)
    reset_time = @authenticated_api_rate_limit_reset_time
    retry_after = [ reset_time - Time.current.to_i, 0 ].max
    reset_at = Time.at(reset_time).iso8601

    response.set_header("Retry-After", retry_after.to_s)
    response.set_header("X-RateLimit-Limit", limit.to_s)
    response.set_header("X-RateLimit-Remaining", "0")
    response.set_header("X-RateLimit-Reset", reset_time.to_s)
    response.set_header("X-RateLimit-Reset-At", reset_at)
    render json: {
      error: "Rate limit exceeded",
      message: "Woah there, way too fast, take a chill pill speedy gonzales!",
      retry_after:,
      reset_at:
    }, status: :too_many_requests
  end
end
