require "application_system_test_case"
require_relative "test_helpers"

class AppearanceSettingsTest < ApplicationSystemTestCase
  include SettingsSystemTestHelpers

  setup do
    @user = User.create!(timezone: "UTC")
    sign_in_as(@user)
  end

  test "appearance settings page renders the theme section" do
    assert_settings_page(
      path: my_settings_appearance_path,
      marker_text: "Theme",
      card_count: 1
    )
  end

  test "appearance settings updates theme without wiping country" do
    @user.update!(country_code: "CA", theme: :gruvbox_dark)

    visit my_settings_appearance_path

    within("#user_theme") do
      click_on "Neon"
      click_on "Save theme"
    end

    assert_text "Settings updated successfully"
    assert_equal "neon", @user.reload.theme
    assert_equal "CA", @user.reload.country_code
  end
end
