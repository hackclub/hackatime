require "test_helper"

# Admins may read a user's stats on the public stats endpoints even when that
# user has turned off allow_public_stats_lookup. These endpoints are anonymously
# accessible, so the credential handling is security sensitive.
class AdminPublicStatsAccessTest < ActionDispatch::IntegrationTest
  setup do
    @private_user = User.create!(username: "priv_#{SecureRandom.hex(4)}",
                                 slack_uid: "U#{SecureRandom.hex(5).upcase}",
                                 timezone: "UTC",
                                 allow_public_stats_lookup: false)
    @private_user.email_addresses.create!(email: "target-#{SecureRandom.hex(4)}@example.com")

    @admin = User.create!(username: "adm_#{SecureRandom.hex(4)}", timezone: "UTC", admin_level: :superadmin)
    @admin.email_addresses.create!(email: "admin-#{SecureRandom.hex(4)}@example.com")
    @admin_key = AdminApiKey.create!(user: @admin, name: "stats bypass test #{SecureRandom.hex(4)}")

    @plain_user = User.create!(username: "pln_#{SecureRandom.hex(4)}", timezone: "UTC")
    @plain_user.email_addresses.create!(email: "plain-#{SecureRandom.hex(4)}@example.com")
    @plain_key = ApiKey.create!(user: @plain_user, name: "plain test key")
  end

  def stats_path = "/api/v1/users/#{@private_user.slack_uid}/stats"
  def bearer(token) = { "Authorization" => "Bearer #{token}" }

  test "anonymous callers cannot read a private user's stats" do
    get stats_path
    assert_response :forbidden
  end

  test "an ordinary user API key cannot read a private user's stats" do
    get stats_path, headers: bearer(@plain_key.token)
    assert_response :forbidden
  end

  test "an admin API key can read a private user's stats" do
    get stats_path, headers: bearer(@admin_key.token)
    assert_response :success
    assert JSON.parse(response.body).key?("data")
  end

  test "an admin API key in the api_key query param is ignored" do
    get stats_path, params: { api_key: @admin_key.token }
    assert_response :forbidden
  end

  test "a revoked admin API key cannot read a private user's stats" do
    @admin_key.revoke!
    get stats_path, headers: bearer(@admin_key.token)
    assert_response :forbidden
  end

  test "a key whose owner lost admin is rejected and revoked" do
    @admin.update!(admin_level: :default)
    get stats_path, headers: bearer(@admin_key.token)
    assert_response :forbidden
    assert_not @admin_key.reload.active?
  end

  test "an admin API key does not authenticate the session as the admin" do
    get stats_path, headers: bearer(@admin_key.token)
    assert_response :success
    assert_nil session[:user_id]
  end

  test "users who allow public stats lookup are still served anonymously" do
    @private_user.update!(allow_public_stats_lookup: true)
    get stats_path
    assert_response :success
  end

  test "admin API key bypasses the privacy gate on the summary endpoint" do
    get "/api/summary", params: { user_id: @private_user.slack_uid, interval: "today" }
    assert_response :forbidden

    get "/api/summary", params: { user_id: @private_user.slack_uid, interval: "today" }, headers: bearer(@admin_key.token)
    assert_response :success
  end

  test "admin API key bypasses the privacy gate on the badge endpoint" do
    get "/api/v1/badge/#{@private_user.slack_uid}/some-project"
    assert_response :forbidden

    get "/api/v1/badge/#{@private_user.slack_uid}/some-project", headers: bearer(@admin_key.token)
    assert_not_equal 403, response.status
  end
end
