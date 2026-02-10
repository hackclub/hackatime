# frozen_string_literal: true

module Inertia
  class DocsIndexPropsSerializer < BaseSerializer
    attribute :popular_editors, type: "Array<[string, string]>"
    attribute :all_editors, type: "Array<[string, string]>"
  end
end
