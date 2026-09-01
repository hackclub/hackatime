require "test_helper"

class Api::V1::Authenticated::HoursControllerTest < ActionDispatch::IntegrationTest
  test "index preserves the documented date defaults" do
    user = create(:user)
    access_token = create_oauth_access_token(user)

    travel_to Time.zone.local(2026, 9, 1, 12) do
      get "/api/v1/authenticated/hours", headers: { "Authorization" => "Bearer #{access_token.token}" }

      assert_response :success
      assert_equal "2026-08-25", response.parsed_body.fetch("start_date")
      assert_equal "2026-09-01", response.parsed_body.fetch("end_date")
    end
  end

  test "index rejects a malformed date range" do
    user = create(:user)
    access_token = create_oauth_access_token(user)

    get "/api/v1/authenticated/hours",
      params: { start_date: "not-a-date" },
      headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :bad_request
    assert_equal({ "error" => "Invalid date range" }, response.parsed_body)
  end

  test "index rejects a reversed date range" do
    user = create(:user)
    access_token = create_oauth_access_token(user)

    get "/api/v1/authenticated/hours",
      params: { start_date: "2025-02-01", end_date: "2025-01-01" },
      headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :bad_request
    assert_equal({ "error" => "Invalid date range" }, response.parsed_body)
  end

  private

  def create_oauth_access_token(user)
    application = create(:oauth_application, owner: user, scopes: "profile read")
    create(:oauth_access_token,
      application: application,
      resource_owner_id: user.id,
      scopes: "profile read",
      expires_in: 16.years)
  end
end
