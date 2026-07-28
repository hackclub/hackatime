require "test_helper"

class Api::V1::StatsControllerTest < ActionDispatch::IntegrationTest
  test "user_stats total_seconds matches full summary total for the same filters" do
    user = User.create!(username: "stats_user_#{SecureRandom.hex(3)}", timezone: "UTC")

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
    user = User.create!(username: "stats_user_#{SecureRandom.hex(3)}", timezone: "UTC")
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
    user = User.create!(username: "private_#{SecureRandom.hex(3)}", timezone: "UTC", allow_public_stats_lookup: false)
    get "/api/v1/users/#{user.username}/heartbeats/spans"
    assert_response :forbidden
  end

  test "user_projects rejects anonymous request when target user has disabled public stats" do
    user = User.create!(username: "private_#{SecureRandom.hex(3)}", timezone: "UTC", allow_public_stats_lookup: false)
    get "/api/v1/users/#{user.username}/projects"
    assert_response :forbidden
  end

  test "user_spans allows anonymous request when target user has public stats enabled" do
    user = User.create!(username: "public_#{SecureRandom.hex(3)}", timezone: "UTC", allow_public_stats_lookup: true)
    get "/api/v1/users/#{user.username}/heartbeats/spans"
    assert_response :success
  end

  test "user_spans allows owner via API token even when public stats disabled" do
    user = User.create!(username: "private_#{SecureRandom.hex(3)}", timezone: "UTC", allow_public_stats_lookup: false)
    api_key = user.api_keys.create!(name: "test")

    get "/api/v1/users/my/heartbeats/spans", headers: { "Authorization" => "Bearer #{api_key.token}" }

    assert_response :success
  end

  test "user_stats allows owner via OAuth token even when public stats disabled" do
    user = User.create!(username: "private_#{SecureRandom.hex(3)}", timezone: "UTC", allow_public_stats_lookup: false)
    access_token = create_oauth_access_token(user, scopes: "profile read")

    get "/api/v1/users/#{user.username}/stats", headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :success
  end

  test "user_stats allows owner via lowercase OAuth bearer scheme" do
    user = User.create!(username: "private_#{SecureRandom.hex(3)}", timezone: "UTC", allow_public_stats_lookup: false)
    access_token = create_oauth_access_token(user, scopes: "profile read")

    get "/api/v1/users/#{user.username}/stats", headers: { "Authorization" => "bearer #{access_token.token}" }

    assert_response :success
  end

  test "user_projects allows owner via OAuth token even when public stats disabled" do
    user = User.create!(username: "private_#{SecureRandom.hex(3)}", timezone: "UTC", allow_public_stats_lookup: false)
    access_token = create_oauth_access_token(user, scopes: "profile read")

    get "/api/v1/users/#{user.username}/projects", headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :success
  end

  test "private read endpoints allow owner via OAuth token" do
    user = User.create!(username: "private_#{SecureRandom.hex(3)}", timezone: "UTC", allow_public_stats_lookup: false)
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
    private_user = User.create!(username: "private_#{SecureRandom.hex(3)}", timezone: "UTC", allow_public_stats_lookup: false)
    other_user = User.create!(username: "other_#{SecureRandom.hex(3)}", timezone: "UTC")
    access_token = create_oauth_access_token(other_user, scopes: "profile read")

    get "/api/v1/users/#{private_user.username}/stats", headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :forbidden
  end

  test "user_stats rejects red owner OAuth token when public stats disabled" do
    user = User.create!(username: "private_#{SecureRandom.hex(3)}", timezone: "UTC", allow_public_stats_lookup: false, trust_level: :red)
    access_token = create_oauth_access_token(user, scopes: "profile read")

    get "/api/v1/users/#{user.username}/stats", headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :forbidden
  end

  test "user_stats rejects pending deletion owner OAuth token when public stats disabled" do
    user = User.create!(username: "private_#{SecureRandom.hex(3)}", timezone: "UTC", allow_public_stats_lookup: false)
    DeletionRequest.create_for_user!(user)
    access_token = create_oauth_access_token(user, scopes: "profile read")

    get "/api/v1/users/#{user.username}/stats", headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :forbidden
  end

  test "user_stats rejects owner OAuth token without read scope when public stats disabled" do
    user = User.create!(username: "private_#{SecureRandom.hex(3)}", timezone: "UTC", allow_public_stats_lookup: false)
    access_token = create_oauth_access_token(user, scopes: "profile")

    get "/api/v1/users/#{user.username}/stats", headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :forbidden
  end

  test "user_stats rejects a different user's API token against a private user's stats" do
    private_user = User.create!(username: "private_#{SecureRandom.hex(3)}", timezone: "UTC", allow_public_stats_lookup: false)
    other_user = User.create!(username: "other_#{SecureRandom.hex(3)}", timezone: "UTC")
    other_key = other_user.api_keys.create!(name: "test")

    get "/api/v1/users/#{private_user.username}/stats", headers: { "Authorization" => "Bearer #{other_key.token}" }

    assert_response :forbidden
  end

  test "user_stats rejects restricted owner API token when public stats disabled" do
    user = User.create!(username: "private_#{SecureRandom.hex(3)}", timezone: "UTC", allow_public_stats_lookup: false, trust_level: :red)
    api_key = user.api_keys.create!(name: "test")

    get "/api/v1/users/#{user.username}/stats", headers: { "Authorization" => "Bearer #{api_key.token}" }

    assert_response :forbidden
  end

  private

  def create_heartbeat(user:, time:, project:, category:)
    Heartbeat.create!(
      user: user,
      source_type: :direct_entry,
      time: time,
      project: project,
      category: category
    )
  end

  def create_oauth_access_token(user, scopes: "profile")
    application = user.oauth_applications.create!(
      name: "Test App",
      redirect_uri: "https://example.com/callback",
      scopes: scopes,
      confidential: true
    )

    Doorkeeper::AccessToken.create!(
      application: application,
      resource_owner_id: user.id,
      scopes: scopes,
      expires_in: 16.years
    )
  end
end
