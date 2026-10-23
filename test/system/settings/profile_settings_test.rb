require "application_system_test_case"
require_relative "test_helpers"

class ProfileSettingsTest < ApplicationSystemTestCase
  include SettingsSystemTestHelpers

  setup do
    @user = create(:user, :with_email)
    sign_in_as(@user)
  end

  test "default settings route renders profile settings page" do
    visit my_settings_path

    assert_current_path my_settings_path, ignore_query: true
    assert_selector "h1", text: "Settings for #{@user.display_name}", exact_text: true
    assert_text "Region and Timezone"
    assert_text "Email Addresses"
    assert_selector "[data-settings-card]", minimum: 3
  end

  test "settings layouts render through SSR and client navigation" do
    settings_url = URI.join(page.current_url, my_settings_profile_path).to_s
    response = page.driver.with_playwright_page do |playwright_page|
      playwright_page.context.request.get(settings_url)
    end
    response_ok = response.ok?
    ssr_body = response.text
    response.dispose

    assert response_ok
    assert_includes ssr_body, 'data-nav-target="nav"'
    assert_includes ssr_body, "data-settings-shell"

    visit my_settings_profile_path
    assert_no_selector '#app > script[type="application/json"]', visible: :all
    page.execute_script("window.settingsNavigationStarted = true")

    within("[data-settings-sidebar]") do
      click_on "Goals"
    end

    assert_current_path my_settings_goals_path, ignore_query: true
    assert_equal true, page.evaluate_script("window.settingsNavigationStarted")
    assert_selector '[data-nav-target="nav"]'
    assert_selector "[data-settings-shell]"
    assert_text "Programming Goals"
  end

  test "profile settings updates country and username" do
    @user.update!(country_code: "CA", username: "old_name")
    new_username = "settings_#{SecureRandom.hex(4)}"
    country_name = ISO3166::Country["US"].common_name

    visit my_settings_profile_path

    choose_select_option("country_code", country_name)
    click_on "Save region settings"
    assert_text "Settings updated successfully"
    assert_equal "US", @user.reload.country_code

    fill_in "Username", with: new_username
    click_on "Save username"
    assert_text "Settings updated successfully"
    assert_equal new_username, @user.reload.username
    assert_equal "US", @user.reload.country_code
  end

  test "profile settings rejects invalid username" do
    @user.update!(username: "good_name")

    visit my_settings_profile_path
    fill_in "Username", with: "bad username!"
    click_on "Save username"

    assert_text "Some changes could not be saved:"
    assert_text "Username may only include letters, numbers, '-', and '_'"
    assert_equal "good_name", @user.reload.username
  end
end
