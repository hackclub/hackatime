# frozen_string_literal: true

class ErrorsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def bad_request
    @status_code = 400
    @title = "Bad Request"
    @message = "The server cannot process your request due to invalid syntax."
    render_error
  end

  def not_found
    @status_code = 404
    @title = "Page Not Found"
    @message = "The page you were looking for doesn't exist. You may have mistyped the address or the page may have moved."
    render_error
  end

  def unprocessable_entity
    @status_code = 422
    @title = "Unprocessable Content"
    @message = "The request was well-formed but unable to be followed due to semantic errors."
    render_error
  end

  def internal_server_error
    @status_code = 500
    @title = "Internal Server Error"
    @message = "Something went wrong on our end, but we are looking into it!"
    @sentry_event_id = Sentry.last_event_id
    render_error
  end

  private

  def render_error
    render "errors/show", status: @status_code, layout: error_layout
  end

  def error_layout
    "errors"
  end
end
