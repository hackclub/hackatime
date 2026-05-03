require "application_system_test_case"
require_relative "test_helpers"

class SetupSettingsTest < ApplicationSystemTestCase
  include SettingsSystemTestHelpers

  setup do
    @user = User.create!(timezone: "UTC")
    @user.api_keys.create!(name: "Initial key")
    sign_in_as(@user)
  end

  test "setup settings page renders setup guide and config file sections" do
    assert_settings_page(
      path: my_settings_setup_path,
      marker_text: "Time Tracking Setup",
      card_count: 2
    )

    assert_text "WakaTime Config File"
  end
end
