require "application_system_test_case"
require_relative "test_helpers"

class PrivacySettingsTest < ApplicationSystemTestCase
  include SettingsSystemTestHelpers

  setup do
    @user = User.create!(timezone: "UTC")
    @user.api_keys.create!(name: "Initial key")
    sign_in_as(@user)
  end

  test "privacy settings page renders key sections" do
    assert_settings_page(
      path: my_settings_privacy_path,
      marker_text: "Public Stats",
      card_count: 3
    )

    assert_text "API Key"
    assert_text "Account Deletion"
  end

  test "privacy settings updates public stats lookup" do
    @user.update!(allow_public_stats_lookup: false)

    visit my_settings_privacy_path

    within("#user_privacy") do
      find("[role='checkbox']").click
      click_on "Save privacy settings"
    end

    assert_text "Settings updated successfully"
    assert_equal true, @user.reload.allow_public_stats_lookup
  end

  test "privacy settings rotate api key can be canceled" do
    old_token = @user.api_keys.order(:id).last.token

    visit my_settings_privacy_path
    click_on "Rotate API key"
    assert_text "Rotate API key?"

    within_modal do
      click_on "Cancel"
    end

    assert_no_text(/New API key/i)
    assert_equal old_token, @user.reload.api_keys.order(:id).last.token
  end

  test "privacy settings redirects to deletion page when request already exists" do
    DeletionRequest.create_for_user!(@user)

    visit my_settings_privacy_path

    assert_current_path deletion_path, ignore_query: true
    assert_text "Account Scheduled for Deletion"
    assert_text "I changed my mind"
  end

  test "privacy settings rotates api key" do
    old_token = @user.api_keys.order(:id).last.token

    visit my_settings_privacy_path
    click_on "Rotate API key"

    within_modal do
      click_on "Rotate key"
    end

    assert_text(/New API key/i)

    new_token = @user.reload.api_keys.order(:id).last.token
    refute_equal old_token, new_token
    assert_equal 1, @user.api_keys.count
    assert_text new_token
  end
end
