# frozen_string_literal: true

module Inertia
  class FlashMessageSerializer < BaseSerializer
    attribute :message, type: :string
    attribute :class_name, type: :string
  end
end
