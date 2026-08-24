require "application_system_test_case"

class AppearanceSettingsTest < ApplicationSystemTestCase
  setup do
    @user = create(:user, :with_email)
    sign_in_as(@user)
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
