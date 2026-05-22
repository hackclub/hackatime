# rack-mini-profiler self-inserts as middleware via its Railtie and instruments
# every request to collect timing/allocation data. In dev that's ~70 KB of
# per-request allocations and a measurable slice of request time — only worth
# paying when you're actively profiling.
#
# Make it opt-in via MINI_PROFILER=1. Production still uses
# Rack::MiniProfiler.authorize_request in ApplicationController for admins.
if Rails.env.development? && ENV["MINI_PROFILER"].blank?
  Rails.application.config.after_initialize do
    if defined?(Rack::MiniProfiler)
      Rack::MiniProfiler.config.enabled = false
    end
  end
end
