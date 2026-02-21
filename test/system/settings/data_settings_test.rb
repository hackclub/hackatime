require "application_system_test_case"
require_relative "test_helpers"

class DataSettingsTest < ApplicationSystemTestCase
  include SettingsSystemTestHelpers

  setup do
    @user = User.create!(timezone: "UTC")
    sign_in_as(@user)
  end

  test "data settings page renders key sections" do
    assert_settings_page(
      path: my_settings_data_path,
      marker_text: "Migration Assistant"
    )

    assert_text "Download Data"
    assert_button "Export all heartbeats"
    assert_button "Export date range"
    assert_text "Account Deletion"
    assert_button "Request deletion"
  end

  test "data settings restricts exports for red trust users" do
    @user.update!(trust_level: :red)

    visit my_settings_data_path

    assert_text "Data export is currently restricted for this account."
    assert_no_button "Export all heartbeats"
    assert_no_button "Export date range"
  end

  test "data settings redirects to deletion page when request already exists" do
    DeletionRequest.create_for_user!(@user)

    visit my_settings_data_path

    assert_current_path deletion_path, ignore_query: true
    assert_text "Account Scheduled for Deletion"
    assert_text "I changed my mind"
  end
end
