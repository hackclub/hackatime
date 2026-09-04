require "test_helper"

class Api::Admin::V1::BansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @superadmin = create(:user, admin_level: :superadmin)
    @key = create(:admin_api_key, user: @superadmin, name: "Telescreen")

    @user = create(:user, timezone: "UTC")
    @cutoff = Time.utc(2026, 3, 1)
    @before_cutoff = build_heartbeat(@cutoff - 2.days, "old-project")
    @after_cutoff = build_heartbeat(@cutoff + 2.days, "new-project")
  end

  def build_heartbeat(time, project)
    create(:heartbeat, user: @user, entity: "src/main.rb", type: "file",
      category: "coding", time: time.to_f, project: project, source_type: :test_entry)
  end

  def auth_headers(key = @key)
    { "Authorization" => ActionController::HttpAuthentication::Token.encode_credentials(key.token) }
  end

  test "poisons heartbeats on or before the posted end date" do
    post "/api/admin/v1/ban/#{@user.id}", params: { date: "2026-03-01" }, headers: auth_headers, as: :json

    assert_response :created
    assert_equal true, response.parsed_body["success"]
    assert_equal 1, response.parsed_body["hidden_heartbeats"]

    assert @user.reload.poisoned?
    assert_not_includes Heartbeat.all, @before_cutoff
    assert_includes Heartbeat.all, @after_cutoff
  end

  test "the end date is inclusive of the named day" do
    on_the_day = build_heartbeat(Time.utc(2026, 3, 1, 23, 30), "ban-day-night")

    post "/api/admin/v1/ban/#{@user.id}", params: { date: "2026-03-01" }, headers: auth_headers, as: :json

    assert_response :created
    assert_not_includes Heartbeat.all, on_the_day
    assert_equal @cutoff + 1.day, @user.reload.poisoned_until.utc
  end

  test "accepts a bare date string as the request body" do
    post "/api/admin/v1/ban/#{@user.id}", params: "2026-03-01",
      headers: auth_headers.merge("Content-Type" => "text/plain")

    assert_response :created
    assert_equal @cutoff + 1.day, @user.reload.poisoned_until.utc
  end

  test "accepts the hackatime id in its other forms" do
    @user.update!(slack_uid: "U12345", username: "banme")

    post "/api/admin/v1/ban/U12345", params: { date: "2026-03-01" }, headers: auth_headers, as: :json
    assert_response :created
    assert @user.reload.poisoned?

    delete "/api/admin/v1/ban/banme", headers: auth_headers, as: :json
    assert_response :success
    assert_not @user.reload.poisoned?
  end

  test "a second ban overwrites the previous end date" do
    post "/api/admin/v1/ban/#{@user.id}", params: { date: "2026-03-01" }, headers: auth_headers, as: :json
    post "/api/admin/v1/ban/#{@user.id}", params: { date: "2026-03-05" }, headers: auth_headers, as: :json

    assert_response :created
    assert_equal Time.utc(2026, 3, 6), @user.reload.poisoned_until.utc
    assert_not_includes Heartbeat.all, @after_cutoff
  end

  test "unbanning restores the hidden heartbeats" do
    post "/api/admin/v1/ban/#{@user.id}", params: { date: "2026-03-01" }, headers: auth_headers, as: :json
    assert_not_includes Heartbeat.all, @before_cutoff

    delete "/api/admin/v1/ban/#{@user.id}", headers: auth_headers, as: :json

    assert_response :success
    assert_nil response.parsed_body["poisoned_until"]
    assert_includes Heartbeat.all, @before_cutoff
  end

  test "unbanning a user who is not banned succeeds without changing anything" do
    delete "/api/admin/v1/ban/#{@user.id}", headers: auth_headers, as: :json

    assert_response :success
    assert_equal true, response.parsed_body["already_unbanned"]
  end

  test "rejects a missing date" do
    post "/api/admin/v1/ban/#{@user.id}", params: {}, headers: auth_headers, as: :json

    assert_response :unprocessable_entity
    assert_not @user.reload.poisoned?
  end

  test "rejects a future end date" do
    post "/api/admin/v1/ban/#{@user.id}", params: { date: (Date.current + 1).to_s }, headers: auth_headers, as: :json

    assert_response :unprocessable_entity
    assert_equal "date cannot be in the future", response.parsed_body["error"]
    assert_not @user.reload.poisoned?
  end

  test "accepts today as an end date" do
    post "/api/admin/v1/ban/#{@user.id}", params: { date: Date.current.to_s }, headers: auth_headers, as: :json

    assert_response :created
    assert @user.reload.poisoned?
  end

  test "rejects an unparseable date rather than poisoning everything" do
    post "/api/admin/v1/ban/#{@user.id}", params: { date: "not-a-date" }, headers: auth_headers, as: :json

    assert_response :unprocessable_entity
    assert_not @user.reload.poisoned?
  end

  test "returns not found for an unknown user" do
    post "/api/admin/v1/ban/nonexistent-user", params: { date: "2026-03-01" }, headers: auth_headers, as: :json

    assert_response :not_found
  end

  test "returns the audit trail in the ban response" do
    post "/api/admin/v1/ban/#{@user.id}",
      params: { date: "2026-03-01", reason: "Telescreen: fabricated heartbeats" },
      headers: auth_headers, as: :json

    assert_response :created
    assert_equal "Telescreen: fabricated heartbeats", response.parsed_body["poison_reason"]
    assert_not_nil response.parsed_body["poisoned_at"]
  end

  test "show reports the current ban state" do
    get "/api/admin/v1/ban/#{@user.id}", headers: auth_headers, as: :json

    assert_response :success
    assert_equal false, response.parsed_body["poisoned"]
    assert_nil response.parsed_body["poisoned_until"]

    @user.apply_poison!(@cutoff, reason: "fabricated heartbeats")

    get "/api/admin/v1/ban/#{@user.id}", headers: auth_headers, as: :json

    assert_response :success
    assert_equal true, response.parsed_body["poisoned"]
    assert_equal "fabricated heartbeats", response.parsed_body["poison_reason"]
    assert_equal 1, response.parsed_body["hidden_heartbeats"]
    assert_not_nil response.parsed_body["poisoned_at"]
  end

  test "show requires a superadmin key" do
    key = create(:admin_api_key, user: create(:user, admin_level: :admin), name: "Admin")

    get "/api/admin/v1/ban/#{@user.id}", headers: auth_headers(key), as: :json

    assert_response :unauthorized
  end


  test "requires an api key" do
    post "/api/admin/v1/ban/#{@user.id}", params: { date: "2026-03-01" }, as: :json

    assert_response :unauthorized
    assert_not @user.reload.poisoned?
  end

  test "an ultraadmin key is allowed" do
    key = create(:admin_api_key, user: create(:user, admin_level: :ultraadmin), name: "Ultra")

    post "/api/admin/v1/ban/#{@user.id}", params: { date: "2026-03-01" }, headers: auth_headers(key), as: :json

    assert_response :created
  end

  test "a plain admin key is rejected" do
    key = create(:admin_api_key, user: create(:user, admin_level: :admin), name: "Admin")

    post "/api/admin/v1/ban/#{@user.id}", params: { date: "2026-03-01" }, headers: auth_headers(key), as: :json

    assert_response :unauthorized
    assert_not @user.reload.poisoned?
  end

  test "a viewer key is rejected" do
    key = create(:admin_api_key, user: create(:user, admin_level: :viewer), name: "Viewer")

    post "/api/admin/v1/ban/#{@user.id}", params: { date: "2026-03-01" }, headers: auth_headers(key), as: :json

    assert_response :unauthorized
    assert_not @user.reload.poisoned?
  end

  test "a non-admin key cannot unban either" do
    @user.apply_poison!(@cutoff)
    key = create(:admin_api_key, user: create(:user, admin_level: :admin), name: "Admin")

    delete "/api/admin/v1/ban/#{@user.id}", headers: auth_headers(key), as: :json

    assert_response :unauthorized
    assert @user.reload.poisoned?
  end

  test "a revoked superadmin key is rejected" do
    @key.revoke!

    post "/api/admin/v1/ban/#{@user.id}", params: { date: "2026-03-01" }, headers: auth_headers, as: :json

    assert_response :unauthorized
    assert_not @user.reload.poisoned?
  end
end
