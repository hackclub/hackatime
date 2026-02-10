# frozen_string_literal: true

JsFromRoutes.config do |config|
  config.client_library = "@js-from-routes/inertia"
  config.file_suffix = "Api.ts"
  config.all_helpers_file = "index.ts"
  config.output_folder = Rails.root.join("app/javascript/api")
end
