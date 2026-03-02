require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Harbor
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    if ENV["RAILS_ENV"] == "test"
      ENV["ENCRYPTION_PRIMARY_KEY"] = "test_primary_key_for_active_record_encryption_123" if ENV["ENCRYPTION_PRIMARY_KEY"].to_s.empty?
      ENV["ENCRYPTION_DETERMINISTIC_KEY"] = "test_deterministic_key_for_active_record_encrypt_456" if ENV["ENCRYPTION_DETERMINISTIC_KEY"].to_s.empty?
      ENV["ENCRYPTION_KEY_DERIVATION_SALT"] = "test_key_derivation_salt_789" if ENV["ENCRYPTION_KEY_DERIVATION_SALT"].to_s.empty?
    end

    config.active_record.encryption.primary_key = ENV["ENCRYPTION_PRIMARY_KEY"]
    config.active_record.encryption.deterministic_key = ENV["ENCRYPTION_DETERMINISTIC_KEY"]
    config.active_record.encryption.key_derivation_salt = ENV["ENCRYPTION_KEY_DERIVATION_SALT"]

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    ActiveSupport::Notifications.subscribe("cache_read.active_support") do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      if event.payload[:hit]
        Thread.current[:cache_hits] ||= 0
        Thread.current[:cache_hits] += 1
      else
        Thread.current[:cache_misses] ||= 0
        Thread.current[:cache_misses] += 1
      end
    end

    ActiveSupport::Notifications.subscribe("cache_fetch_hit.active_support") do |*args|
      Thread.current[:cache_hits] += 1
    end

    config.active_job.queue_adapter = :good_job

    config.session_store :cookie_store,
      key: "_hackatime_session",
      expire_after: 14.days,
      secure: Rails.env.production?,
      httponly: true

    config.middleware.use Rack::Attack
    config.exceptions_app = routes
  end
end
