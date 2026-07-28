require "test_helper"

class Admin::LeaderboardShadowbansControllerTest < ActionDispatch::IntegrationTest
  test "index is not routed for viewers" do
    viewer = User.create!(timezone: "UTC", admin_level: :viewer)
    sign_in_as(viewer)

    get admin_leaderboard_shadowbans_path

    assert_response :not_found
  end

  test "index renders for regular admins" do
    admin = User.create!(timezone: "UTC", admin_level: :admin)
    sign_in_as(admin)

    get admin_leaderboard_shadowbans_path

    assert_response :success
    assert_inertia_component "Admin/LeaderboardShadowbans"
  end

  test "index renders current shadowbanned users" do
    admin = User.create!(timezone: "UTC", admin_level: :superadmin)
    user = User.create!(timezone: "UTC", username: "already_shadowbanned")
    expires_at = 2.days.from_now
    PaperTrail.request(whodunnit: admin.id) do
      user.set_leaderboard_shadowban(banned: true, changed_by_user: admin, reason: "inflated activity", expires_at: expires_at)
    end
    sign_in_as(admin)

    get admin_leaderboard_shadowbans_path

    assert_response :success
    assert_inertia_component "Admin/LeaderboardShadowbans"
    body_user = inertia_page.dig("props", "shadowbanned_users").first
    assert_equal user.id, body_user["id"]
    assert_equal "inflated activity", body_user["leaderboard_shadowban_reason"]
    assert_equal expires_at.iso8601, body_user["leaderboard_shadowban_expires_at"]
    assert_equal admin.id, body_user.dig("shadowbanned_by", "id")
    assert_equal "superadmin", body_user.dig("shadowbanned_by", "admin_level")
    assert_not body_user.fetch("shadowbanned_by").key?("email")
  end

  test "search_users returns shadowban metadata" do
    admin = User.create!(timezone: "UTC", admin_level: :superadmin)
    user = User.create!(
      timezone: "UTC",
      username: "shadowban_search",
      leaderboard_shadowbanned: true,
      leaderboard_shadowban_reason: "fake data"
    )
    sign_in_as(admin)

    get search_users_admin_leaderboard_shadowbans_path, params: { query: "shadowban_search" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body.length
    assert_equal user.id, body.first["id"]
    assert_equal true, body.first["leaderboard_shadowbanned"]
    assert_equal "fake data", body.first["leaderboard_shadowban_reason"]
  end

  test "create leaderboard shadowbans a user with PaperTrail whodunnit" do
    admin = User.create!(timezone: "UTC", admin_level: :superadmin)
    user = User.create!(timezone: "UTC", username: "shadowban_create")
    expires_at = 1.week.from_now
    sign_in_as(admin)

    assert_difference -> { PaperTrail::Version.where(item_type: "User", item_id: user.id).count }, 1 do
      post admin_leaderboard_shadowbans_path, params: {
        user_id: user.id,
        reason: "fake leaderboard activity",
        leaderboard_shadowban_expires_at: expires_at.iso8601
      }
    end

    assert_redirected_to admin_leaderboard_shadowbans_path
    assert user.reload.leaderboard_shadowbanned?
    assert_equal "fake leaderboard activity", user.leaderboard_shadowban_reason
    assert_equal admin, user.leaderboard_shadowbanned_by
    assert_equal expires_at.to_i, user.leaderboard_shadowban_expires_at.to_i
    assert_equal admin.id.to_s, PaperTrail::Version.where(item_type: "User", item_id: user.id).last.whodunnit
  end

  test "create rejects invalid automatic unshadowban time" do
    admin = User.create!(timezone: "UTC", admin_level: :superadmin)
    user = User.create!(timezone: "UTC", username: "shadowban_bad_exp")
    sign_in_as(admin)

    post admin_leaderboard_shadowbans_path, params: {
      user_id: user.id,
      reason: "fake leaderboard activity",
      leaderboard_shadowban_expires_at: "not a time"
    }

    assert_redirected_to admin_leaderboard_shadowbans_path
    assert_not user.reload.leaderboard_shadowbanned?
  end

  test "create requires reason" do
    admin = User.create!(timezone: "UTC", admin_level: :superadmin)
    user = User.create!(timezone: "UTC", username: "shadowban_reason")
    sign_in_as(admin)

    post admin_leaderboard_shadowbans_path, params: { user_id: user.id, reason: "" }

    assert_redirected_to admin_leaderboard_shadowbans_path
    assert_not user.reload.leaderboard_shadowbanned?
  end

  test "destroy removes leaderboard shadowban" do
    admin = User.create!(timezone: "UTC", admin_level: :superadmin)
    user = User.create!(
      timezone: "UTC",
      username: "shadowban_destroy",
      leaderboard_shadowbanned: true,
      leaderboard_shadowban_reason: "fake data"
    )
    sign_in_as(admin)

    delete admin_leaderboard_shadowban_path(user)

    assert_redirected_to admin_leaderboard_shadowbans_path
    assert_not user.reload.leaderboard_shadowbanned?
    assert_nil user.leaderboard_shadowban_reason
    assert_nil user.leaderboard_shadowbanned_by
    assert_nil user.leaderboard_shadowban_expires_at
  end
end
