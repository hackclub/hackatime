class MaintenanceModeMiddleware
  MAINTENANCE_PAGE = Rails.root.join("public", "maintenance.html").freeze
  SKIP_PATHS = %w[/up /maintenance].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    if ENV["MAINTENANCE_MODE"].present? && !SKIP_PATHS.include?(env["PATH_INFO"])
      content = File.read(MAINTENANCE_PAGE)
      [ 503, { "Content-Type" => "text/html", "Retry-After" => "1200" }, [ content ] ]
    else
      @app.call(env)
    end
  end
end
