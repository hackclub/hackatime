if defined?(RailsPerformance)
  RailsPerformance.setup do |config|
    # Redis is required for rails_performance
    config.redis = Redis.new(url: ENV["REDIS_URL"].presence || "redis://127.0.0.1:6379/0")
    config.duration = 4.hours

    # Custom data to track
    config.custom_data_proc = lambda do |env|
      request = Rack::Request.new(env)
      data = {}

      # Track current user if available
      if request.session && request.session["user_id"]
        user = User.find_by(id: request.session["user_id"])
        if user
          data[:user_id] = user.id
          data[:username] = user.username
          data[:user_admin] = user.admin?
        end
      end

      # Track HTTP User Agent
      data[:user_agent] = request.user_agent

      # Track IP address
      data[:remote_ip] = request.ip

      # Track referer
      data[:referer] = request.referer

      data
    end

    # Skip certain paths
    config.ignored_paths = [ "/good_job", "/rails/health", "/assets", "/rails/performance" ]

    # Enable monitoring for all environments (you might want to restrict this)
    config.enabled = true
  end
end
