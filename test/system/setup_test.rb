require "application_system_test_case"

class SetupTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(timezone: "UTC")
    sign_in_as(@user)
  end

  test "old wakatime_setup routes redirect to /setup" do
    visit "/my/wakatime_setup"
    assert_current_path "/setup"
    assert_text "Welcome to Hackatime!"
  end

  test "terminal flow shows the setup command with per-OS tabs" do
    visit setup_path

    assert_text "Welcome to Hackatime!"
    click_on "Yes, I have an editor installed"

    assert_text "Are you comfortable with pasting a setup script in your terminal, or would you like to manually install each extension?"
    click_on "Terminal (automatic)"

    # Non-Windows user agents default to a Unix shell command.
    assert_text "curl -fsSL"

    click_on "Windows"
    assert_text "install.ps1"
    assert_text "type \"PowerShell\""

    click_on "macOS"
    assert_text "curl -fsSL"
    assert_text "Spotlight"

    click_on "Linux"
    assert_text "curl -fsSL"
    assert_text "Ctrl + Alt + T"

    click_on "WSL"
    assert_text "curl -fsSL"
    assert_text "type wsl"

    click_on "I'm done!"
    assert_text "Fair Play Policy"
  end

  test "codespaces flow walks through the extension install" do
    visit setup_path

    click_on "No, I don't have an editor installed"
    assert_text "Are you able to install programs on your computer?"

    click_on "No, I can't download programs"
    assert_text "github.com/codespaces"

    click_on "Continue"
    assert_text "Install \"Hackatime Time Tracker\""

    click_on "I'm done!"
    assert_text "Fair Play Policy"
  end
end
