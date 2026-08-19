# frozen_string_literal: true

# Generates path helpers from Rails routes for the Inertia/Svelte frontend.
# See https://js-from-routes.netlify.app for documentation.
#
# Routes are exported by marking them in config/routes.rb: pass `export: true`
# on an individual route or `resources` call, or wrap a group of routes in a
# `defaults export: true do ... end` block. To use a newly exported route from
# JS, refresh the page (or run `bin/rake js_from_routes:generate` in
# development).
return unless defined?(JsFromRoutes)

JsFromRoutes.config do |config|
  # Emit TypeScript files into `app/javascript/api/`.
  config.file_suffix = "Api.ts"
end
