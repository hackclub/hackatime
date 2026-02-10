# frozen_string_literal: true

module Inertia
  class HomeSignedOutPropsSerializer < BaseSerializer
    attribute :flavor_text, type: :string
    attribute :hca_auth_path, type: :string
    attribute :slack_auth_path, type: :string
    attribute :email_auth_path, type: :string
    attribute :sign_in_email, type: :boolean
    attribute :show_dev_tool, type: :boolean
    attribute :dev_magic_link, type: "string | null"
    attribute :csrf_token, type: :string
    attribute :home_stats, type: "Record<string, unknown>"
  end
end
