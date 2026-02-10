# frozen_string_literal: true

module Inertia
  class LayoutPropsSerializer < BaseSerializer
    has_one :nav, serializer: Inertia::LayoutNavSerializer
    has_one :footer, serializer: Inertia::FooterSerializer
    has_one :currently_hacking, serializer: Inertia::CurrentlyHackingSerializer
    attribute :csrf_token, type: :string
    attribute :signout_path, type: :string
    attribute :show_stop_impersonating, type: :boolean
    attribute :stop_impersonating_path, type: :string
  end
end
