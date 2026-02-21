require "application_system_test_case"
require_relative "test_helpers"

class IntegrationsSettingsTest < ApplicationSystemTestCase
  include SettingsSystemTestHelpers

  setup do
    @user = User.create!(timezone: "UTC")
    sign_in_as(@user)
  end

  test "integrations settings page renders key sections" do
    assert_settings_page(
      path: my_settings_integrations_path,
      marker_text: "Slack Status Sync"
    )

    assert_text "Slack Channel Notifications"
    assert_text "Connected GitHub Account"
    assert_text "Email Addresses"
  end

  test "integrations settings updates slack status sync preference" do
    @user.update!(uses_slack_status: false)

    visit my_settings_integrations_path

    within("#user_slack_status") do
      find("[role='checkbox']").click
      click_on "Save Slack settings"
    end

    assert_text "Settings updated successfully"
    assert_equal true, @user.reload.uses_slack_status
  end

  test "integrations settings opens and cancels unlink github modal" do
    @user.update!(
      github_uid: "12345",
      github_username: "octocat",
      github_access_token: "github-token"
    )

    visit my_settings_integrations_path
    assert_text "@octocat"

    click_on "Unlink GitHub"
    within_modal do
      assert_text "Unlink GitHub account?"
      click_on "Cancel"
    end

    assert_current_path my_settings_integrations_path, ignore_query: true
    assert_text "@octocat"
  end
end
