# frozen_string_literal: true

module Inertia
  class CurrentlyHackingUserSerializer < BaseSerializer
    attribute :id, type: :number
    attribute :display_name, type: "string | null"
    attribute :slack_uid, type: "string | null"
    attribute :avatar_url, type: "string | null"
    attribute :active_project, type: "Record<string, unknown> | null"
  end
end
