require "test_helper"

class Api::V1::Authenticated::HoursControllerTest < ActionDispatch::IntegrationTest
  test "index reads whole-day totals from serving tables" do
    user = User.create!(timezone: "UTC")
    access_token = create_oauth_access_token(user)

    create_heartbeat(user:, time: Time.utc(2026, 7, 1, 9, 0, 0).to_f, project: "hours", category: "coding")
    create_heartbeat(user:, time: Time.utc(2026, 7, 1, 9, 2, 0).to_f, project: "hours", category: "coding")
    create_heartbeat(user:, time: Time.utc(2026, 7, 2, 9, 0, 0).to_f, project: "hours", category: "coding")
    create_heartbeat(user:, time: Time.utc(2026, 7, 2, 9, 1, 0).to_f, project: "hours", category: "coding")

    heartbeat_queries = collect_heartbeat_queries do
      get "/api/v1/authenticated/hours",
        params: { start_date: "2026-07-01", end_date: "2026-07-02" },
        headers: { "Authorization" => "Bearer #{access_token.token}" }
    end

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal "2026-07-01", payload.fetch("start_date")
    assert_equal "2026-07-02", payload.fetch("end_date")
    assert_equal 300, payload.fetch("total_seconds")
    assert_empty heartbeat_queries
  end

  private

  def create_heartbeat(user:, time:, project:, category:)
    super(
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

  def collect_heartbeat_queries
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      sql = payload[:sql].to_s
      queries << sql if sql.match?(/\bFROM\s+`?heartbeats`?\b/i)
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
