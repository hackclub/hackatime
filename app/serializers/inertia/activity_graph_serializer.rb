# frozen_string_literal: true

module Inertia
  class ActivityGraphSerializer < BaseSerializer
    attribute :start_date, type: :string
    attribute :end_date, type: :string
    attribute :duration_by_date, type: "Record<string, number>"
    attribute :busiest_day_seconds, type: :number
    attribute :timezone_label, type: :string
    attribute :timezone_settings_path, type: :string
  end
end
