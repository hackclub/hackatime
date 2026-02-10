# frozen_string_literal: true

module Inertia
  class DocsShowPropsSerializer < BaseSerializer
    attribute :doc_path, type: :string
    attribute :title, type: :string
    attribute :rendered_content, type: :string
    has_many :breadcrumbs, serializer: Inertia::DocsBreadcrumbSerializer
    attribute :edit_url, type: :string
    has_one :meta, serializer: Inertia::DocsMetaSerializer
  end
end
