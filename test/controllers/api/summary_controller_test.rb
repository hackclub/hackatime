require "test_helper"

class Api::SummaryControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user, username: "summary_#{SecureRandom.hex(3)}", allow_public_stats_lookup: true)
  end

  test "index rejects a malformed one-sided explicit range instead of using the default" do
    get "/api/summary", params: { user_id: @user.username, from: "not-a-date" }

    assert_response :bad_request
    assert_equal({ "error" => "Invalid date range" }, response.parsed_body)
  end

  test "index rejects a reversed explicit range" do
    get "/api/summary", params: {
      user_id: @user.username,
      from: "2025-02-01",
      to: "2025-01-01"
    }

    assert_response :bad_request
    assert_equal({ "error" => "Invalid date range" }, response.parsed_body)
  end
end
