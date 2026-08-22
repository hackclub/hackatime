require "application_system_test_case"

class AdminUsersTest < ApplicationSystemTestCase
  setup do
    @ultraadmin = User.create!(timezone: "UTC", admin_level: :ultraadmin)
    @target = User.create!(
      timezone: "UTC",
      display_name_override: "Search Target",
      slack_uid: "USEARCHTARGET"
    )
    sign_in_as(@ultraadmin)
  end

  test "search results identify the user and style every role action" do
    visit admin_admin_users_path

    fill_in "Search by name or Slack ID...", with: "Search Target"

    assert_text "USEARCHTARGET"
    assert_text "Default"
    assert_selector "button.bg-purple-400", text: "→ Ultraadmin"
  end

  test "an ultraadmin can promote a searched user" do
    visit admin_admin_users_path

    fill_in "Search by name or Slack ID...", with: "Search Target"
    click_button "→ Admin"

    assert_text "Search Target's admin level updated to admin."
    assert_equal "admin", @target.reload.admin_level
  end

  test "an admin can start impersonating from a migrated user mention" do
    application = @target.oauth_applications.create!(
      name: "Target App",
      redirect_uri: "https://example.com/callback",
      scopes: "profile",
      confidential: true
    )

    visit admin_oauth_application_path(application)
    click_link "Impersonate Search Target"

    assert_current_path root_path, ignore_query: true
    assert_text "Stop impersonating"
  end
end
