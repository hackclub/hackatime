# frozen_string_literal: true

TypesFromSerializers.config do |config|
  config.output_dir = Rails.root.join("app/javascript/types/serializers")
  config.custom_types_dir = Rails.root.join("app/javascript/types")
  config.transform_keys = ->(key) { key.to_s }
end
