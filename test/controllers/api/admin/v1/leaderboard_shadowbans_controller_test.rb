require "test_helper"

class Api::Admin::V1::LeaderboardShadowbansControllerTest < ActionDispatch::IntegrationTest
  test "index requires a shadowban-capable admin API key" do
    admin = User.create!(timezone: "UTC", admin_level: :admin)
    key = admin.admin_api_keys.create!(name: "test")

    get "/api/admin/v1/leaderboard_shadowbans", headers: auth_headers(key)

    assert_response :forbidden
  end

  test "create requires a shadowban-capable admin API key" do
    admin = User.create!(timezone: "UTC", admin_level: :admin)
    key = admin.admin_api_keys.create!(name: "test")
    user = User.create!(timezone: "UTC", username: "shadowban_create_403")

    post "/api/admin/v1/leaderboard_shadowbans", params: { user_id: user.id, reason: "fake leaderboard activity" }, headers: auth_headers(key), as: :json

    assert_response :forbidden
    assert_not user.reload.leaderboard_shadowbanned?
  end

  test "destroy requires a shadowban-capable admin API key" do
    superadmin = User.create!(timezone: "UTC", admin_level: :superadmin)
    admin = User.create!(timezone: "UTC", admin_level: :admin)
    key = admin.admin_api_keys.create!(name: "test")
    user = User.create!(timezone: "UTC", username: "shadowban_destroy403")
    user.set_leaderboard_shadowban(banned: true, changed_by_user: superadmin, reason: "fake leaderboard activity")

    delete "/api/admin/v1/leaderboard_shadowbans/#{user.id}", headers: auth_headers(key)

    assert_response :forbidden
    assert user.reload.leaderboard_shadowbanned?
  end

  test "index lists leaderboard shadowbanned users" do
    admin = User.create!(timezone: "UTC", admin_level: :superadmin)
    key = admin.admin_api_keys.create!(name: "test")
    user = User.create!(timezone: "UTC", username: "api_shadowbanned")
    user.set_leaderboard_shadowban(banned: true, changed_by_user: admin, reason: "inflated activity")

    get "/api/admin/v1/leaderboard_shadowbans", headers: auth_headers(key)

    assert_response :success
    body_user = response.parsed_body.fetch("leaderboard_shadowbans").first
    assert_equal user.id, body_user["id"]
    assert_equal "inflated activity", body_user["leaderboard_shadowban_reason"]
    assert_equal admin.id, body_user.dig("shadowbanned_by", "id")
  end

  test "search_users returns shadowban metadata" do
    admin = User.create!(timezone: "UTC", admin_level: :superadmin)
    key = admin.admin_api_keys.create!(name: "test")
    user = User.create!(
      timezone: "UTC",
      username: "api_shadowban_search"
    )
    user.set_leaderboard_shadowban(banned: true, changed_by_user: admin, reason: "fake data")

    get "/api/admin/v1/leaderboard_shadowbans/search_users", params: { query: "api_shadowban_search" }, headers: auth_headers(key)

    assert_response :success
    body_user = response.parsed_body.fetch("users").first
    assert_equal user.id, body_user["id"]
    assert_equal true, body_user["leaderboard_shadowbanned"]
    assert_equal "fake data", body_user["leaderboard_shadowban_reason"]
    assert_equal admin.id, body_user.dig("shadowbanned_by", "id")
  end

  test "create leaderboard shadowbans a user with PaperTrail whodunnit" do
    admin = User.create!(timezone: "UTC", admin_level: :superadmin)
    key = admin.admin_api_keys.create!(name: "test")
    user = User.create!(timezone: "UTC", username: "api_shadowban_create")

    assert_difference -> { PaperTrail::Version.where(item_type: "User", item_id: user.id).count }, 1 do
      post "/api/admin/v1/leaderboard_shadowbans", params: { user_id: user.id, reason: "fake leaderboard activity" }, headers: auth_headers(key), as: :json
    end

    assert_response :created
    assert user.reload.leaderboard_shadowbanned?
    assert_equal "fake leaderboard activity", user.leaderboard_shadowban_reason
    assert_equal admin, user.leaderboard_shadowbanned_by
    assert_equal admin.id.to_s, PaperTrail::Version.where(item_type: "User", item_id: user.id).last.whodunnit
    assert_equal true, response.parsed_body.fetch("success")
  end

  test "create requires reason" do
    admin = User.create!(timezone: "UTC", admin_level: :superadmin)
    key = admin.admin_api_keys.create!(name: "test")
    user = User.create!(timezone: "UTC", username: "api_shadowban_reason")

    post "/api/admin/v1/leaderboard_shadowbans", params: { user_id: user.id, reason: "" }, headers: auth_headers(key), as: :json

    assert_response :unprocessable_entity
    assert_not user.reload.leaderboard_shadowbanned?
    assert_includes response.parsed_body.fetch("errors"), "Leaderboard shadowban reason can't be blank"
  end

  test "destroy removes leaderboard shadowban" do
    admin = User.create!(timezone: "UTC", admin_level: :superadmin)
    key = admin.admin_api_keys.create!(name: "test")
    user = User.create!(
      timezone: "UTC",
      username: "api_shadowban_destroy",
      leaderboard_shadowbanned: true,
      leaderboard_shadowban_reason: "fake data"
    )

    delete "/api/admin/v1/leaderboard_shadowbans/#{user.id}", headers: auth_headers(key)

    assert_response :success
    assert_not user.reload.leaderboard_shadowbanned?
    assert_nil user.leaderboard_shadowban_reason
    assert_nil user.leaderboard_shadowbanned_by
  end

  private

  def auth_headers(key)
    { "Authorization" => ActionController::HttpAuthentication::Token.encode_credentials(key.token) }
  end
end
