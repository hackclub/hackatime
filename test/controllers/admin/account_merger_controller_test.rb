require "test_helper"

class Admin::AccountMergerControllerTest < ActionDispatch::IntegrationTest
  test "search_users returns formatted user results" do
    admin = User.create!(timezone: "UTC", admin_level: :ultraadmin)
    user = User.create!(timezone: "UTC", username: "merge_target")
    user.email_addresses.create!(email: "merge-target@example.com", source: :signing_in)
    sign_in_as(admin)

    get search_users_admin_account_merger_path, params: { query: "merge_target" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body.length
    assert_equal user.id, body.first["id"]
    assert_equal user.display_name, body.first["display_name"]
    assert_equal user.avatar_url, body.first["avatar_url"]
    assert_equal user.username, body.first["username"]
    assert_equal "merge-target@example.com", body.first["email"]
    assert_equal user.created_at.strftime("%Y-%m-%d"), body.first["created_at"]
  end

  test "merge does not double count revoked doorkeeper rows in success message" do
    admin = User.create!(timezone: "UTC", admin_level: :ultraadmin)
    older = User.create!(timezone: "UTC", username: "older_user")
    newer = User.create!(timezone: "UTC", username: "newer_user")
    sign_in_as(admin)

    heartbeat = Heartbeat.create!(user: newer, time: Time.current.to_i, source_type: :test_entry)
    api_key = ApiKey.create!(user: newer, name: "Merge Test Key")
    newer.email_addresses.create!(email: "newer@example.com", source: :signing_in)
    newer.sign_in_tokens.create!(auth_type: :email)
    oauth_app = newer.oauth_applications.create!(
      name: "Merge Test App",
      redirect_uri: "https://example.com/callback",
      scopes: "profile",
      confidential: true
    )
    Doorkeeper::AccessToken.create!(
      application: oauth_app,
      resource_owner_id: newer.id,
      scopes: "profile",
      expires_in: 1.hour.to_i
    )
    Doorkeeper::AccessGrant.create!(
      application: oauth_app,
      resource_owner_id: newer.id,
      redirect_uri: oauth_app.redirect_uri,
      scopes: "profile",
      expires_in: 10.minutes.to_i
    )

    post merge_admin_account_merger_path, params: { older_id: older.id, newer_id: newer.id }

    assert_redirected_to admin_account_merger_path
    assert_equal 1, Heartbeat.where(user_id: older.id).count
    assert_equal heartbeat.id, Heartbeat.find_by(user_id: older.id)&.id
    assert_equal older.id, ApiKey.find(api_key.id).user_id
    assert_nil User.find_by(id: newer.id)
    assert_equal 0, Doorkeeper::AccessToken.where(resource_owner_id: newer.id).count
    assert_equal 0, Doorkeeper::AccessGrant.where(resource_owner_id: newer.id).count
    assert_includes flash[:notice], "3 sessions/tokens revoked"
    assert_includes flash[:notice], "3 related records cleaned up"
  end

  test "merge renames transferred api keys when the older account already has the same key name" do
    admin = User.create!(timezone: "UTC", admin_level: :ultraadmin)
    older = User.create!(timezone: "UTC", username: "older_user")
    newer = User.create!(timezone: "UTC", username: "newer_user")
    sign_in_as(admin)

    older.update_column(:created_at, 2.days.ago)
    newer.update_column(:created_at, 1.day.ago)

    older.api_keys.create!(name: "Wakatime API Key")
    transferred_key = newer.api_keys.create!(name: "Wakatime API Key")

    post merge_admin_account_merger_path, params: { older_id: older.id, newer_id: newer.id }

    assert_redirected_to admin_account_merger_path
    assert_nil User.find_by(id: newer.id)
    assert_equal older.id, transferred_key.reload.user_id
    assert_equal "Wakatime API Key (transferred)", transferred_key.name
    assert_equal [ "Wakatime API Key", "Wakatime API Key (transferred)" ], older.api_keys.order(:name).pluck(:name)
  end
end
