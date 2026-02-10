# frozen_string_literal: true

module Inertia
  class SspUserSerializer < BaseSerializer
    attribute :id, type: :number
    attribute :avatar_url, type: :string
    attribute :display_name, type: :string
  end
end
