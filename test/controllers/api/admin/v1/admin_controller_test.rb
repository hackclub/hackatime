require "test_helper"

class Api::Admin::V1::AdminControllerTest < ActionDispatch::IntegrationTest
  test "user heartbeats returns ja4 fingerprint and name" do
    admin = User.create!(timezone: "UTC", admin_level: :superadmin)
    key = admin.admin_api_keys.create!(name: "test")
    user = User.create!(timezone: "UTC", username: "admin_heartbeats_ja4")
    ja4 = Ja4.create!(fingerprint: "t13d1312h2_f57a46bbacb6_ab7e3b40a677", name: "Go net/http")

    user.heartbeats.create!(
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
