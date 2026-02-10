# frozen_string_literal: true

module Inertia
  class WakatimeSetupIndexPropsSerializer < BaseSerializer
    attribute :current_user_api_key, type: "string | null"
    attribute :setup_os, type: :string
    attribute :api_url, type: :string
    attribute :heartbeat_check_url, type: :string
  end
end
