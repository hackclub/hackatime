# frozen_string_literal: true

# Shared JSON error rendering helpers used across API and HTML controllers.
# Use `render_error("msg", status: :forbidden)` instead of repeating
# `render json: { error: "..." }, status: :...` everywhere.
module RenderHelpers
  extend ActiveSupport::Concern

  # Render a JSON error response. Returns nil so callers can early-return easily.
  def render_error(message, status: :unprocessable_entity)
    render json: { error: message }, status: status
    nil
  end

  def render_unauthorized(message = "Unauthorized")
    render_error(message, status: :unauthorized)
  end

  def render_forbidden(message = "lmao no perms")
    render_error(message, status: :forbidden)
  end

  def render_not_found_json(message = "Not found")
    render_error(message, status: :not_found)
  end

  def render_bad_request(message)
    render_error(message, status: :bad_request)
  end
end
