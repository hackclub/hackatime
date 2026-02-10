# frozen_string_literal: true

module Inertia
  class DocsMetaSerializer < BaseSerializer
    attribute :description, type: :string
    attribute :keywords, type: :string
  end
end
