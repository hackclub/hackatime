require "test_helper"

class My::HeartbeatsControllerTest < ActionDispatch::IntegrationTest
  test "export rejects banned users" do
    user = User.create!(trust_level: :red)
    user.email_addresses.create!(email: "banned-export@example.com", source: :signing_in)
    sign_in_as(user)

    post export_my_heartbeats_path, params: { all_data: "true" }

    assert_response :redirect
    assert_redirected_to my_settings_path
    assert_equal "Sorry, you are not permitted to this action.", flash[:alert]
  end

  test "export rejects invalid start date format" do
    user = User.create!
    user.email_addresses.create!(email: "invalid-start-date@example.com", source: :signing_in)
    sign_in_as(user)

    post export_my_heartbeats_path, params: {
      all_data: "false",
      start_date: "not-a-date",
      end_date: Date.current.iso8601
    }

    assert_response :redirect
    assert_redirected_to my_settings_data_path
    assert_equal "Invalid date format. Please use YYYY-MM-DD.", flash[:alert]
  end

  test "export rejects start date after end date" do
    user = User.create!
    user.email_addresses.create!(email: "invalid-range@example.com", source: :signing_in)
    sign_in_as(user)

    post export_my_heartbeats_path, params: {
      all_data: "false",
      start_date: Date.current.iso8601,
      end_date: 1.day.ago.to_date.iso8601
    }

    assert_response :redirect
    assert_redirected_to my_settings_data_path
    assert_equal "Start date must be on or before end date.", flash[:alert]
  end
end
