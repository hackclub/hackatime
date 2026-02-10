# frozen_string_literal: true

module Inertia
  class LayoutNavSerializer < BaseSerializer
    has_many :flash, serializer: Inertia::FlashMessageSerializer
    attribute :user_present, type: :boolean
    attribute :user_mention_html, type: "string | null"
    attribute :streak_html, type: "string | null"
    attribute :admin_level_html, type: "string | null"
    attribute :login_path, type: :string
    has_many :links, serializer: Inertia::NavLinkSerializer
    has_many :dev_links, serializer: Inertia::NavLinkSerializer
    has_many :admin_links, serializer: Inertia::NavLinkSerializer
    has_many :viewer_links, serializer: Inertia::NavLinkSerializer
    has_many :superadmin_links, serializer: Inertia::NavLinkSerializer
    attribute :activities_html, type: "string | null"
  end
end
