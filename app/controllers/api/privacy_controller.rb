class Api::PrivacyController < ActionController::API
  def delete = process_privacy_request("delete")
  def export = process_privacy_request("export")

  private

  def process_privacy_request(action)
    response.headers["Cache-Control"] = "no-store"
    authorization = request.get_header("HTTP_AUTHORIZATION").to_s
    match = authorization.match(/\ABearer ([^\s]+)\z/i)
    claims = Privacy::Token.verify(match&.[](1), action: action)
    request.env["privacy.request_id"] = claims.fetch("request_id")
    PrivacyTokenUse.consume!(claims.fetch("jti"))
    result = Privacy::Eraser.new(claims).call(action: action)
    request.env["privacy.outcome"] = action == "export" ? "exported" : (claims["dry_run"] ? "dry_run" : "deleted")
    render json: result
  rescue Privacy::Error => error
    request.env["privacy.outcome"] = error.message
    render json: { error: error.message }, status: error.status
  rescue StandardError
    # Do not forward exceptions with SQL binds, storage keys or claims to Sentry.
    request.env["privacy.outcome"] = "internal_error"
    render json: { error: "internal_error" }, status: :internal_server_error
  end
end
