# frozen_string_literal: true

module Inertia
  class DocsBreadcrumbSerializer < BaseSerializer
    attribute :name, type: :string
    attribute :href, type: "string | null"
    attribute :is_link, type: :boolean
  end
end
