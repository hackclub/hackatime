require "test_helper"

class Api::Admin::V1::TimelineControllerTest < ActionDispatch::IntegrationTest
  test "show includes the current admin with an empty timeline when no users are selected" do
    admin = create(:user, :admin)
    key = create(:admin_api_key, user: admin, name: "test")

    get "/api/admin/v1/timeline", headers: auth_headers(key)

    assert_response :success
    assert_equal [ admin.id ], response.parsed_body.fetch("users").pluck("user").pluck("id")
    assert_empty response.parsed_body.dig("users", 0, "spans")
  end

  test "show rejects a malformed date instead of falling back" do
    admin = create(:user, :admin)
    key = create(:admin_api_key, user: admin, name: "test")

    get "/api/admin/v1/timeline", params: { date: "not-a-date" }, headers: auth_headers(key)

    assert_response :unprocessable_entity
    assert_equal({ "error" => "Invalid date format" }, response.parsed_body)
  end

  test "search_users returns an error object for a blank query" do
    admin = create(:user, :admin)
    key = create(:admin_api_key, user: admin, name: "test")

    get "/api/admin/v1/timeline/search_users", params: { query: "" }, headers: auth_headers(key)

    assert_response :unprocessable_entity
    assert_equal({ "error" => "Query parameter is required" }, response.parsed_body)
  end

  private

  def auth_headers(key)
    { "Authorization" => ActionController::HttpAuthentication::Token.encode_credentials(key.token) }
  end
end
