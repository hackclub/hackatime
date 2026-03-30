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

    assert_kind_of Integer, summary_total
    assert_equal summary_total, total_only, "total_seconds endpoint should match summary total_seconds"
  end

  test "user_stats excludes heartbeats exactly at the end_date boundary" do
    user = User.create!(username: "boundary_user_#{SecureRandom.hex(3)}", timezone: "UTC")

    create_heartbeat(user:, time: Time.utc(2025, 12, 15, 23, 59, 0).to_f, project: "Boundary", category: "coding")
    create_heartbeat(user:, time: Time.utc(2025, 12, 16, 0, 0, 0).to_f, project: "Boundary", category: "coding")

    params = {
      features: "projects",
      filter_by_project: "Boundary",
      start_date: "2025-12-15T00:00:00Z",
      end_date: "2025-12-16T00:00:00Z"
    }

    get "/api/v1/users/#{user.username}/stats", params: params

    assert_response :success
    assert_equal 0, JSON.parse(response.body).dig("data", "total_seconds")

    get "/api/v1/users/#{user.username}/stats", params: params.merge(total_seconds: "true")

    assert_response :success
    assert_equal 0, JSON.parse(response.body).fetch("total_seconds")
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
