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

    sql_queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      sql_queries << payload[:sql]
    end

    get "/api/v1/users/#{user.username}/stats", params: {
      features: "projects",
      filter_by_project: "Galactic_war",
      start_date: "2025-12-15",
      end_date: "2025-12-16"
    }

    assert_response :success
    assert sql_queries.none? { |sql| sql.match?(/SELECT "heartbeats"\."id", "heartbeats"\."user_id"/) }
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
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
end
