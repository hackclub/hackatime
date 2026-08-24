require "test_helper"

class Api::V1::StatsControllerTest < ActionDispatch::IntegrationTest
  test "user_stats total_seconds matches full summary total for the same filters" do
    user = create(:user, username: "stats_user_#{SecureRandom.hex(3)}")

    create_heartbeat(user:, time: Time.utc(2025, 12, 15, 10, 0, 0).to_f, project: "Galactic_war", category: "coding")
    create_heartbeat(user:, time: Time.utc(2025, 12, 15, 10, 1, 40).to_f, project: "Galactic_war", category: "browsing")
    create_heartbeat(user:, time: Time.utc(2025, 12, 15, 10, 3, 40).to_f, project: "Galactic_war", category: "coding")

    params = {
      features: "projects",
      filter_by_project: "Galactic_war",
      start_date: "2025-12-15",
      end_date: "2025-12-16"
    }

    get "/api/v1/users/#{user.username}/stats", params: params

    assert_response :success
    summary_total = JSON.parse(response.body).dig("data", "total_seconds")

    get "/api/v1/users/#{user.username}/stats", params: params.merge(total_seconds: "true")

    assert_response :success
    total_only = JSON.parse(response.body).fetch("total_seconds")

    assert_equal 220, summary_total
    assert_equal summary_total, total_only
  end

  test "user_stats with project filter does not load heartbeat records" do
    user = create(:user, username: "stats_user_#{SecureRandom.hex(3)}")
    create_heartbeat(user:, time: Time.utc(2025, 12, 15, 10, 0, 0).to_f, project: "Galactic_war", category: "coding")
    create_heartbeat(user:, time: Time.utc(2025, 12, 15, 10, 1, 0).to_f, project: "Galactic_war", category: "coding")

    instantiated_heartbeats = 0
    subscriber = ActiveSupport::Notifications.subscribe("instantiation.active_record") do |*, payload|
      instantiated_heartbeats += payload[:record_count] if payload[:class_name] == "Heartbeat"
    end

    get "/api/v1/users/#{user.username}/stats", params: {
      features: "projects",
      filter_by_project: "Galactic_war",
      start_date: "2025-12-15",
      end_date: "2025-12-16"
    }

    assert_response :success
    assert_equal 0, instantiated_heartbeats
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "user_spans rejects anonymous request when target user has disabled public stats" do
    user = create(:user, username: "private_#{SecureRandom.hex(3)}", allow_public_stats_lookup: false)
    get "/api/v1/users/#{user.username}/heartbeats/spans"
    assert_response :forbidden
  end

  test "user_projects rejects anonymous request when target user has disabled public stats" do
    user = create(:user, username: "private_#{SecureRandom.hex(3)}", allow_public_stats_lookup: false)
    get "/api/v1/users/#{user.username}/projects"
    assert_response :forbidden
  end

  test "user_spans allows anonymous request when target user has public stats enabled" do
    user = create(:user, username: "public_#{SecureRandom.hex(3)}", allow_public_stats_lookup: true)
    get "/api/v1/users/#{user.username}/heartbeats/spans"
    assert_response :success
  end

  test "user_spans allows owner via API token even when public stats disabled" do
    user = create(:user, username: "private_#{SecureRandom.hex(3)}", allow_public_stats_lookup: false)
    api_key = create(:api_key, user: user, name: "test")

    get "/api/v1/users/my/heartbeats/spans", headers: { "Authorization" => "Bearer #{api_key.token}" }

    assert_response :success
  end

  test "user_stats allows owner via OAuth token even when public stats disabled" do
    user = create(:user, username: "private_#{SecureRandom.hex(3)}", allow_public_stats_lookup: false)
    access_token = create_oauth_access_token(user, scopes: "profile read")

    get "/api/v1/users/#{user.username}/stats", headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :success
  end

  test "user_stats allows owner via lowercase OAuth bearer scheme" do
    user = create(:user, username: "private_#{SecureRandom.hex(3)}", allow_public_stats_lookup: false)
    access_token = create_oauth_access_token(user, scopes: "profile read")

    get "/api/v1/users/#{user.username}/stats", headers: { "Authorization" => "bearer #{access_token.token}" }

    assert_response :success
  end

  test "user_projects allows owner via OAuth token even when public stats disabled" do
    user = create(:user, username: "private_#{SecureRandom.hex(3)}", allow_public_stats_lookup: false)
    access_token = create_oauth_access_token(user, scopes: "profile read")

    get "/api/v1/users/#{user.username}/projects", headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :success
  end

  test "private read endpoints allow owner via OAuth token" do
    user = create(:user, username: "private_#{SecureRandom.hex(3)}", allow_public_stats_lookup: false)
    create_heartbeat(user:, time: Time.current.to_f, project: "Galactic_war", category: "coding")
    access_token = create_oauth_access_token(user, scopes: "profile read")
    headers = { "Authorization" => "Bearer #{access_token.token}" }

    get "/api/v1/users/#{user.username}/heartbeats/spans", headers: headers
    assert_response :success

    get "/api/v1/users/#{user.username}/project/Galactic_war", headers: headers
    assert_response :success

    get "/api/v1/users/#{user.username}/projects/details", params: { projects: "Galactic_war" }, headers: headers
    assert_response :success
  end

  test "user_stats rejects a different user's OAuth token against a private user's stats" do
    private_user = create(:user, username: "private_#{SecureRandom.hex(3)}", allow_public_stats_lookup: false)
    other_user = create(:user, username: "other_#{SecureRandom.hex(3)}")
    access_token = create_oauth_access_token(other_user, scopes: "profile read")

    get "/api/v1/users/#{private_user.username}/stats", headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :forbidden
  end

  test "user_stats rejects red owner OAuth token when public stats disabled" do
    user = create(:user, username: "private_#{SecureRandom.hex(3)}", allow_public_stats_lookup: false, trust_level: :red)
    access_token = create_oauth_access_token(user, scopes: "profile read")

    get "/api/v1/users/#{user.username}/stats", headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :forbidden
  end

  test "user_stats rejects pending deletion owner OAuth token when public stats disabled" do
    user = create(:user, username: "private_#{SecureRandom.hex(3)}", allow_public_stats_lookup: false)
    DeletionRequest.create_for_user!(user)
    access_token = create_oauth_access_token(user, scopes: "profile read")

    get "/api/v1/users/#{user.username}/stats", headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :forbidden
  end

  test "user_stats rejects owner OAuth token without read scope when public stats disabled" do
    user = create(:user, username: "private_#{SecureRandom.hex(3)}", allow_public_stats_lookup: false)
    access_token = create_oauth_access_token(user, scopes: "profile")

    get "/api/v1/users/#{user.username}/stats", headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :forbidden
  end

  test "user_stats rejects a different user's API token against a private user's stats" do
    private_user = create(:user, username: "private_#{SecureRandom.hex(3)}", allow_public_stats_lookup: false)
    other_user = create(:user, username: "other_#{SecureRandom.hex(3)}")
    other_key = create(:api_key, user: other_user, name: "test")

    get "/api/v1/users/#{private_user.username}/stats", headers: { "Authorization" => "Bearer #{other_key.token}" }

    assert_response :forbidden
  end

  test "user_stats rejects restricted owner API token when public stats disabled" do
    user = create(:user, username: "private_#{SecureRandom.hex(3)}", allow_public_stats_lookup: false, trust_level: :red)
    api_key = create(:api_key, user: user, name: "test")

    get "/api/v1/users/#{user.username}/stats", headers: { "Authorization" => "Bearer #{api_key.token}" }

    assert_response :forbidden
  end

  test "aggregate stats accepts active admin API keys only from the header" do
    admin_api_key = create_admin_api_key

    get "/api/v1/stats", headers: { "Authorization" => "Bearer #{admin_api_key.token}" }
    assert_response :success

    get "/api/v1/stats", headers: { "Authorization" => "bearer #{admin_api_key.token}" }
    assert_response :success

    get "/api/v1/stats", params: { api_key: admin_api_key.token }
    assert_response :unauthorized
  end

  test "aggregate stats rejects valid admin API keys under non-Bearer schemes" do
    admin_api_key = create_admin_api_key

    [ "Basic #{admin_api_key.token}", "Token #{admin_api_key.token}", admin_api_key.token ].each do |authorization|
      get "/api/v1/stats", headers: { "Authorization" => authorization }
      assert_response :unauthorized
    end
  end

  test "aggregate stats rejects revoked admin API keys" do
    admin_api_key = create_admin_api_key
    admin_api_key.revoke!

    get "/api/v1/stats", headers: { "Authorization" => "Bearer #{admin_api_key.token}" }

    assert_response :unauthorized
  end

  test "aggregate stats accepts STATS_API_KEY only while legacy flag is enabled" do
    previous_stats_api_key = ENV["STATS_API_KEY"]
    legacy_key = "legacy-stats-#{SecureRandom.hex(8)}"
    ENV["STATS_API_KEY"] = legacy_key
    Flipper.disable(:allow_legacy_stats_api_key)

    get "/api/v1/stats", headers: { "Authorization" => "Bearer #{legacy_key}" }
    assert_response :unauthorized
    get "/api/v1/stats", params: { api_key: legacy_key }
    assert_response :unauthorized

    Flipper.enable(:allow_legacy_stats_api_key)
    get "/api/v1/stats", headers: { "Authorization" => "Bearer #{legacy_key}" }
    assert_response :success
    get "/api/v1/stats", headers: { "Authorization" => "bearer #{legacy_key}" }
    assert_response :success
    get "/api/v1/stats", params: { api_key: legacy_key }
    assert_response :success

    [ "Basic #{legacy_key}", "Token #{legacy_key}", legacy_key, "Bearer\t#{legacy_key}" ].each do |authorization|
      get "/api/v1/stats", headers: { "Authorization" => authorization }
      assert_response :unauthorized
    end

    [ "", " ", "Token malformed" ].each do |authorization|
      get "/api/v1/stats",
        params: { api_key: legacy_key },
        headers: { "Authorization" => authorization }
      assert_response :unauthorized
    end

    get "/api/v1/users/lookup_email/nobody@example.com", params: { api_key: legacy_key }
    assert_response :unauthorized

    admin_api_key = create_admin_api_key
    get "/api/v1/stats", params: { api_key: admin_api_key.token }
    assert_response :unauthorized
  ensure
    Flipper.disable(:allow_legacy_stats_api_key)
    ENV["STATS_API_KEY"] = previous_stats_api_key
  end

  private

  def create_admin_api_key
    user = create(:user, :admin, username: "stats_admin_#{SecureRandom.hex(3)}")
    create(:admin_api_key, user: user, name: "Stats integration")
  end

  def create_heartbeat(user:, time:, project:, category:)
    create(:heartbeat,
      user: user,
      source_type: :direct_entry,
      time: time,
      project: project,
      category: category
    )
  end

  def create_oauth_access_token(user, scopes: "profile")
    application = create(:oauth_application, owner: user,
      name: "Test App",
      redirect_uri: "https://example.com/callback",
      scopes: scopes,
      confidential: true
    )

    create(:oauth_access_token,
      application: application,
      resource_owner_id: user.id,
      scopes: scopes,
      expires_in: 16.years
    )
  end
end
