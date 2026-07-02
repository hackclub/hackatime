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

  test "terminal flow shows the setup command with an OS toggle" do
    visit setup_path

    assert_text "Welcome to Hackatime!"
    click_on "Yes!"

    assert_text "Are you comfortable with pasting a setup script in your terminal, or would you like to manually install each extension?"
    click_on "Terminal (automatic)"

    # Non-Windows user agent defaults to the macOS / Linux command
    assert_text "curl -fsSL"

    click_on "Windows"
    assert_text "install.ps1"

    click_on "I'm done!"
    assert_text "Fair Play Policy"
  end

  test "codespaces flow walks through the extension install" do
    visit setup_path

    click_on "Nope!"
    assert_text "Are you able to install programs on your computer?"

    click_on "No"
    assert_text "github.com/codespaces"

    click_on "I'm done!"
    assert_text "Install \"Hackatime Time Tracker\""

    click_on "I'm done!"
    assert_text "Fair Play Policy"
  end
end
