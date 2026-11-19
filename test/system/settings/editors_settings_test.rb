require "application_system_test_case"
require_relative "test_helpers"

class EditorsSettingsTest < ApplicationSystemTestCase
  include SettingsSystemTestHelpers

  setup do
    @user = create(:user, :with_email)
    sign_in_as(@user)
  end

  test "editors settings updates extension display style" do
    visit my_settings_editors_path

    choose_select_option("extension_type", "Clock emoji")
    assert_selector "[role='checkbox'][disabled]"
    click_on "Save extension settings"

    assert_text "Settings updated successfully"
    assert_equal "clock_emoji", @user.reload.hackatime_extension_text_type
  end

  test "editors settings restores server values after a rejected update" do
    @user.update!(
      hackatime_extension_text_type: :simple_text,
      show_goals_in_statusbar: false
    )

    visit my_settings_editors_path
    @user.update_column(:country_code, "ZZ")

    find("[role='checkbox']").click
    choose_select_option("extension_type", "Clock emoji")
    click_on "Save extension settings"

    assert_text "Country code is not included in the list"

    choose_select_option("extension_type", "Simple text")
    assert_selector "[role='checkbox'][aria-checked='false']:not([disabled])"
  end
end
