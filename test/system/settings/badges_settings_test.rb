require "application_system_test_case"
require_relative "test_helpers"

class BadgesSettingsTest < ApplicationSystemTestCase
  include SettingsSystemTestHelpers

  setup do
    @user = User.create!(timezone: "UTC")
    sign_in_as(@user)
  end

  test "badges settings page renders key sections" do
    assert_settings_page(
      path: my_settings_badges_path,
      marker_text: "Stats Badges"
    )

    assert_text "Markscribe Template"
    assert_text "Activity Heatmap"
  end

  test "badges settings updates general badge preview theme" do
    visit my_settings_badges_path

    choose_select_option("badge_theme", "default")

    assert_text(/theme=default/i)
  end
end
