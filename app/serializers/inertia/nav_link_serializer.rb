# frozen_string_literal: true

module Inertia
  class NavLinkSerializer < BaseSerializer
    attribute :label, type: :string
    attribute :href, type: :string, optional: true
    attribute :active, type: :boolean, optional: true
    attribute :badge, type: "number | null", optional: true
    attribute :action, type: :string, optional: true
  end
end
