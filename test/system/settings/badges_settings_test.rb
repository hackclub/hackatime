require "application_system_test_case"
require_relative "test_helpers"

class BadgesSettingsTest < ApplicationSystemTestCase
  include SettingsSystemTestHelpers

  setup do
    @user = create(:user, :with_email)
    sign_in_as(@user)
  end

  test "badges settings page renders key sections" do
    assert_settings_page(
      path: my_settings_badges_path,
      marker_text: "Stats Badges",
      card_count: 3
    )

    assert_text "Markscribe Template"
    assert_text "Activity Heatmap"
  end

  test "badges settings updates general badge preview theme" do
    visit my_settings_badges_path

    choose_select_option("badge_theme", "default")

    assert_text(/theme=default/i)
  end

  test "badges settings enables public stats" do
    @user.update!(allow_public_stats_lookup: false)

    visit my_settings_badges_path
    click_on "Enable public stats"

    assert_text "Settings updated successfully"
    assert_equal true, @user.reload.allow_public_stats_lookup
  end
end
