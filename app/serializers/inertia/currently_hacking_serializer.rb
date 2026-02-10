# frozen_string_literal: true

module Inertia
  class CurrentlyHackingSerializer < BaseSerializer
    attribute :count, type: :number
    has_many :users, serializer: Inertia::CurrentlyHackingUserSerializer
    attribute :interval, type: :number
  end
end
