require "application_system_test_case"

class WakatimeSetupTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(timezone: "UTC")
    sign_in_as(@user)
  end

  test "shows OS switcher tabs and can switch between them" do
    visit my_wakatime_setup_path

    # Default tab should be macOS / Linux / Codespaces (non-Windows user agent)
    assert_text "Configure Hackatime"
    assert_text "curl -fsSL"

    # Switch to Windows tab
    click_on "Windows"
    assert_text "Open PowerShell"
    assert_text "install.ps1"

    # Switch to Advanced tab
    click_on "Advanced"
    assert_text "~/.wakatime.cfg"
    assert_text "api_url"

    # Switch back to macOS / Linux tab
    click_on "macOS / Linux"
    assert_text "curl -fsSL"
  end
end
