# frozen_string_literal: true

InertiaRails.configure do |config|
  config.version = ViteRuby.digest
  config.encrypt_history = Rails.env.production?
  config.always_include_errors_hash = true
  config.use_script_element_for_initial_page = true
  config.use_data_inertia_head_attribute = true
  config.expose_shared_prop_keys = true
  config.ssr_enabled = ViteRuby.config.ssr_build_enabled
  config.ssr_bundle = ViteRuby.config.ssr_output_dir.join("ssr.js")
  config.ssr_runtime = "bun"
end
