# frozen_string_literal: true

module Inertia
  class DocsNotFoundPropsSerializer < BaseSerializer
    attribute :status_code, type: :number
    attribute :title, type: :string
    attribute :message, type: :string
  end
end
