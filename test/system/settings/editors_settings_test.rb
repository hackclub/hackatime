require "application_system_test_case"
require_relative "test_helpers"

class EditorsSettingsTest < ApplicationSystemTestCase
  include SettingsSystemTestHelpers

  setup do
    @user = User.create!(timezone: "UTC")
    sign_in_as(@user)
  end

  test "editors settings page renders the extension display section" do
    assert_settings_page(
      path: my_settings_editors_path,
      marker_text: "Extension Display",
      card_count: 1
    )
  end

  test "editors settings updates extension display style" do
    visit my_settings_editors_path

    choose_select_option("extension_type", "Clock emoji")
    click_on "Save extension settings"

    assert_text "Settings updated successfully"
    assert_equal "clock_emoji", @user.reload.hackatime_extension_text_type
  end
end
