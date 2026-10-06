# frozen_string_literal: true

module AuthenticatedApiRateLimiting
  extend ActiveSupport::Concern

  LIMIT = 300
  PERIOD = 1.minute.to_i

  FAILURE_STATUSES = [ 401, 403 ].freeze

  included do
    # Rack::Attack skips these paths, so rejected credentials are limited by IP
    # here, before authentication runs.
    prepend_around_action :limit_authenticated_api_failures, unless: :rack_attack_safelisted?

    rate_limit to: LIMIT, within: PERIOD,
      by: :authenticated_api_rate_limit_discriminator,
      with: :render_authenticated_api_rate_limit_exceeded,
      scope: "authenticated-api",
      unless: :rack_attack_safelisted?
  end

  private

  def rack_attack_safelisted? = request.env["rack.attack.match_type"] == :safelist

  def limit_authenticated_api_failures
    key = "authenticated-api-failures:#{request.remote_ip}:#{authenticated_api_rate_limit_window}"
    return render_authenticated_api_rate_limit_exceeded if cache_store.read(key).to_i >= LIMIT

    yield
    cache_store.increment(key, 1, expires_in: PERIOD) if response.status.in?(FAILURE_STATUSES)
  end

  def authenticated_api_rate_limit_discriminator
    "#{authenticated_api_rate_limit_identity}:#{authenticated_api_rate_limit_window}"
  end

  def authenticated_api_rate_limit_window
    window = Time.current.to_i / PERIOD
    @authenticated_api_rate_limit_reset_time = (window + 1) * PERIOD
    window
  end

  def render_authenticated_api_rate_limit_exceeded
    reset_time = @authenticated_api_rate_limit_reset_time
    retry_after = [ reset_time - Time.current.to_i, 0 ].max
    reset_at = Time.at(reset_time).iso8601

    response.set_header("Retry-After", retry_after.to_s)
    response.set_header("X-RateLimit-Limit", LIMIT.to_s)
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
