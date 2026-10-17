require "application_system_test_case"
require_relative "test_helpers"

class SetupSettingsTest < ApplicationSystemTestCase
  include SettingsSystemTestHelpers

  setup do
    @user = create(:user, :with_email)
    create(:api_key, user: @user, name: "Initial key")
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

  test "setup settings preserves the no-key message without creating a key" do
    @user.api_keys.destroy_all

    visit my_settings_setup_path

    assert_text "No API key is available yet. Rotate your API key from Privacy & Security to generate one."
    assert_equal 0, @user.api_keys.count
  end
end
