# frozen_string_literal: true

module Inertia
  class WakatimeSetupStep3PropsSerializer < BaseSerializer
    attribute :current_user_api_key, type: "string | null"
    attribute :editor, type: "string | null"
    attribute :heartbeat_check_url, type: :string
  end
end
