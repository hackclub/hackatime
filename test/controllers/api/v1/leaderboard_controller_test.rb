require "test_helper"

class Api::V1::LeaderboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
  end

  teardown do
    Rails.cache.clear
  end

  test "daily leaderboard excludes leaderboard shadowbanned users and reranks visible entries" do
    visible_user = create_user(username: "api_lb_visible")
    hidden_user = create_user(username: "api_lb_hidden", leaderboard_shadowbanned: true)
    board = create_board(period_type: :daily)
    board.entries.create!(user: hidden_user, total_seconds: 500)
    board.entries.create!(user: visible_user, total_seconds: 300)

    get "/api/v1/leaderboard/daily"

    assert_response :success
    entries = JSON.parse(response.body).fetch("entries")
    assert_equal [ visible_user.id ], entries.map { |entry| entry.dig("user", "id") }
    assert_equal [ 1 ], entries.map { |entry| entry["rank"] }
  end

  test "weekly leaderboard excludes leaderboard shadowbanned users" do
    visible_user = create_user(username: "api_lb_week_visible")
    hidden_user = create_user(username: "api_lb_week_hidden", leaderboard_shadowbanned: true)
    board = create_board(period_type: :last_7_days)
    board.entries.create!(user: visible_user, total_seconds: 300)
    board.entries.create!(user: hidden_user, total_seconds: 200)

    get "/api/v1/leaderboard/weekly"

    assert_response :success
    entries = JSON.parse(response.body).fetch("entries")
    assert_equal [ visible_user.id ], entries.map { |entry| entry.dig("user", "id") }
  end

  private

  def create_user(username:, leaderboard_shadowbanned: false)
    User.create!(
      username: username,
      timezone: "UTC",
      leaderboard_shadowbanned: leaderboard_shadowbanned,
      leaderboard_shadowban_reason: leaderboard_shadowbanned ? "test shadowban" : nil
    )
  end

  def create_board(period_type:)
    Leaderboard.create!(
      start_date: LeaderboardDateRange.normalize_date(Date.current, period_type),
      period_type: period_type,
      timezone_utc_offset: nil,
      finished_generating_at: Time.current
    )
  end
end
