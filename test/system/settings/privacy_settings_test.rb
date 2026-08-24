require "application_system_test_case"
require_relative "test_helpers"

class PrivacySettingsTest < ApplicationSystemTestCase
  include SettingsSystemTestHelpers

  setup do
    @user = create(:user, :with_email)
    create(:api_key, user: @user, name: "Initial key")
    @oauth_application = create(
      :oauth_application,
      owner: @user,
      name: "Test Integration",
      redirect_uri: "https://example.com/callback",
      scopes: "profile",
      confidential: true
    )
    @access_token = create(:oauth_access_token,
      application: @oauth_application,
      resource_owner_id: @user.id,
      scopes: "profile",
      expires_in: 1.hour.to_i
    )
    sign_in_as(@user)
  end

  test "privacy settings page renders key sections" do
    assert_settings_page(
      path: my_settings_privacy_path,
      marker_text: "Public Stats",
      card_count: 4
    )

    assert_text "Authorized Applications"
    assert_text "Test Integration"
    assert_text "API Key"
    assert_text "Account Deletion"
  end

  test "privacy settings revokes an authorized application" do
    visit my_settings_privacy_path

    within("#authorized_applications") do
      accept_confirm { click_on "Revoke" }
    end

    assert_text "Application access revoked"
    assert_no_text "Test Integration"
    assert_predicate @access_token.reload, :revoked?
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

    within("[role='dialog']") do
      click_on "Cancel"
    end

    assert_no_text(/New API key/i)
    assert_equal old_token, @user.reload.api_keys.order(:id).last.token
  end

  test "privacy settings redirects to deletion page when request already exists" do
    DeletionRequest.create_for_user!(@user)

    visit my_settings_privacy_path

    assert_current_path deletion_path, ignore_query: true
    assert_text "Account scheduled for deletion"
    assert_text "I changed my mind"
  end

  test "privacy settings rotates api key" do
    old_token = @user.api_keys.order(:id).last.token

    visit my_settings_privacy_path
    click_on "Rotate API key"

    within("[role='dialog']") do
      click_on "Rotate key"
    end

    assert_text(/New API key/i)
    assert_no_text "Unable to rotate API key"

    new_token = @user.reload.api_keys.order(:id).last.token
    refute_equal old_token, new_token
    assert_equal 1, @user.api_keys.count
    assert_text new_token
  end
end
