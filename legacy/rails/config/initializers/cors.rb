Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"

    # Allow CORS for the hackatime API endpoints
    resource "/api/*",
      headers: :any,
      methods: [ :get, :post, :options ],
      max_age: 600
  end
end
