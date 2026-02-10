# frozen_string_literal: true

module Inertia
  class ActiveUsersGraphEntrySerializer < BaseSerializer
    attribute :height, type: :number
    attribute :title, type: :string
  end
end
