require "test_helper"

class LeaderboardPageCacheTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  teardown do
    Rails.cache.clear
  end

  test "fetch caches serialized global leaderboard rows" do
    user = create_user(username: "lbcacheuser", country_code: "US", trust_level: :green)
    board = create_board_with_entry(user: user, total_seconds: 321)

    payload = LeaderboardPageCache.fetch(leaderboard: board, scope: :global)

    assert_equal 1, payload[:total_entries]
    assert_equal [ user.id ], payload[:user_ids]
    assert_equal 321, payload[:entries].first[:total_seconds]
    assert_equal user.display_name, payload[:entries].first.dig(:user, :display_name)
    assert_equal true, payload[:entries].first.dig(:user, :verified)
  end

  test "fetch filters country scoped rows" do
    us_user = create_user(username: "lbcache_us", country_code: "US")
    ca_user = create_user(username: "lbcache_ca", country_code: "CA")
    board = create_board
    board.entries.create!(user: us_user, total_seconds: 300)
    board.entries.create!(user: ca_user, total_seconds: 200)

    payload = LeaderboardPageCache.fetch(leaderboard: board, scope: :country, country_code: "US")

    assert_equal 1, payload[:total_entries]
    assert_equal [ us_user.id ], payload[:user_ids]
  end

  private

  def create_user(username:, country_code:, trust_level: :blue)
    User.create!(
      username: username,
      country_code: country_code,
      timezone: "UTC",
      trust_level: trust_level
    )
  end

  def create_board
    Leaderboard.create!(
      start_date: Date.current,
      period_type: :daily,
      timezone_utc_offset: nil,
      finished_generating_at: Time.current
    )
  end

  def create_board_with_entry(user:, total_seconds:)
    board = create_board
    board.entries.create!(user: user, total_seconds: total_seconds, streak_count: 2)
    board
  end
end
