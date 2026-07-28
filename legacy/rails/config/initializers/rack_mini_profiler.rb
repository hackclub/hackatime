if Rails.env.development? && ENV["MINI_PROFILER"].blank?
  Rails.application.config.after_initialize do
    if defined?(Rack::MiniProfiler)
      Rack::MiniProfiler.config.enabled = false
    end
  end

  Rails.application.config.middleware.delete(Rack::MiniProfiler)
end
