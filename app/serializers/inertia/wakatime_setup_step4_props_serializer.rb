# frozen_string_literal: true

module Inertia
  class WakatimeSetupStep4PropsSerializer < BaseSerializer
    attribute :dino_video_url, type: :string
    attribute :return_url, type: "string | null"
    attribute :return_button_text, type: :string
  end
end
