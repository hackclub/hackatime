require "test_helper"

class Api::Admin::V1::HeartbeatsControllerTest < ActionDispatch::IntegrationTest
  test "user heartbeats returns ja4 fingerprint and name" do
    admin = create(:user, :superadmin)
    key = create(:admin_api_key, user: admin, name: "test")
    user = create(:user, username: "admin_heartbeats_ja4")
    ja4 = create(:ja4, fingerprint: "t13d1312h2_f57a46bbacb6_ab7e3b40a677", name: "Go net/http")

    create(:heartbeat,
      user: user,
      time: Time.current.to_i,
      project: "test-project",
      entity: "test.rb",
      source_type: :direct_entry,
      ja4: ja4
    )

    get "/api/admin/v1/user/heartbeats", params: { user_id: user.id }, headers: auth_headers(key)

    assert_response :success
    response_ja4 = response.parsed_body.fetch("heartbeats").first.fetch("ja4")
    assert_equal "t13d1312h2_f57a46bbacb6_ab7e3b40a677", response_ja4.fetch("fingerprint")
    assert_equal "Go net/http", response_ja4.fetch("name")
  end

  private

  def auth_headers(key)
    { "Authorization" => ActionController::HttpAuthentication::Token.encode_credentials(key.token) }
  end
end
