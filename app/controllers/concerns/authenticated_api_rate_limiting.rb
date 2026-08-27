# frozen_string_literal: true

module AuthenticatedApiRateLimiting
  extend ActiveSupport::Concern

  included do
    rate_limit to: 300, within: 1.minute,
      by: :authenticated_api_rate_limit_identity,
      with: :render_authenticated_api_rate_limit_exceeded,
      scope: "authenticated-api"
  end

  private

  def render_authenticated_api_rate_limit_exceeded
    response.set_header("Retry-After", "60")
    render json: { error: "Rate limit exceeded" }, status: :too_many_requests
  end
end
