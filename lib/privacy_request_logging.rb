# Run outside Rails' request/SQL logging and error-reporting middleware. The only
# privacy log is emitted after leaving the silenced request, without its payload.
class PrivacyRequestLogging
  def initialize(app)
    @app = app
  end

  def call(env)
    privacy_request = Rack::Utils.unescape_path(env["PATH_INFO"].to_s).squeeze("/").start_with?("/api/privacy/")
    return @app.call(env) unless privacy_request

    previous = Thread.current[:privacy_request]
    Thread.current[:privacy_request] = true
    result = Rails.logger.silence(Logger::UNKNOWN) do
      ActiveRecord::Base.logger.silence(Logger::UNKNOWN) { @app.call(env) }
    end
    Rails.logger.info({ request_id: env["privacy.request_id"], outcome: env["privacy.outcome"] || "rejected" }.to_json)
    result
  ensure
    Thread.current[:privacy_request] = previous if privacy_request
  end
end
