# frozen_string_literal: true

module Inertia
  class HomeSignedInPropsSerializer < BaseSerializer
    attribute :flavor_text, type: :string
    attribute :trust_level_red, type: :boolean
    attribute :show_wakatime_setup_notice, type: :boolean
    attribute :ssp_message, type: "string | null"
    has_many :ssp_users_recent, serializer: Inertia::SspUserSerializer
    attribute :ssp_users_size, type: :number
    attribute :github_uid_blank, type: :boolean
    attribute :github_auth_path, type: :string
    attribute :wakatime_setup_path, type: :string
    attribute :show_logged_time_sentence, type: :boolean
    attribute :todays_duration_display, type: :string
    attribute :todays_languages, type: "string[]"
    attribute :todays_editors, type: "string[]"
    attribute :filterable_dashboard_data, type: "Record<string, unknown>"
    has_one :activity_graph, serializer: Inertia::ActivityGraphSerializer
  end
end
