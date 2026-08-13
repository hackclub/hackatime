class DocumentationCacheControl
  MUTABLE_PATH_PREFIXES = %w[
    /agent-readability.json
    /blume-search.json
    /docs
    /llms
    /og/docs
  ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    if %w[GET HEAD].include?(env["REQUEST_METHOD"]) && env["PATH_INFO"].start_with?(*MUTABLE_PATH_PREFIXES)
      headers["cache-control"] = "public, max-age=0, must-revalidate"
    end
    [ status, headers, body ]
  end
end
