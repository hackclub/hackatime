# frozen_string_literal: true

InertiaRails.configure do |config|
  # The official partial-reload test helpers do not send X-Inertia-Version.
  config.version = ViteRuby.digest unless Rails.env.test?
  config.encrypt_history = Rails.env.production?
  config.always_include_errors_hash = true
  # Required for Inertia.js v3 client compatibility. Defaults are still `false`
  # in inertia_rails 3.x; will become the only behavior in inertia_rails 4.0.
  config.use_script_element_for_initial_page = true
  config.use_data_inertia_head_attribute = true
  config.ssr_enabled = true
  config.ssr_raise_on_error = ENV["INERTIA_SYSTEM_TEST"] == "1"
end
