require "test_helper"

class LeaderboardEntriesTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  teardown do
    Rails.cache.clear
  end

  test "fetch hides leaderboard shadowbanned entries from public viewers and reranks visible entries" do
    hidden_user = create_user(username: "entries_hidden", leaderboard_shadowbanned: true)
    visible_user = create_user(username: "entries_visible")
    board = create_board
    board.entries.create!(user: hidden_user, total_seconds: 500, streak_count: 1)
    board.entries.create!(user: visible_user, total_seconds: 300, streak_count: 2)

    payload = LeaderboardEntries.fetch(leaderboard: board)

    assert_equal 1, payload[:total]
    assert_equal [ visible_user.id ], payload[:entries].map { |entry| entry[:user_id] }
    assert_equal [ 1 ], payload[:entries].map { |entry| entry[:rank] }
  end

  test "fetch shows a leaderboard shadowbanned entry to its own user" do
    hidden_user = create_user(username: "entries_self", leaderboard_shadowbanned: true)
    board = create_board
    board.entries.create!(user: hidden_user, total_seconds: 500, streak_count: 1)

    payload = LeaderboardEntries.fetch(leaderboard: board, viewer: hidden_user)

    assert_equal 1, payload[:total]
    assert_equal hidden_user.id, payload[:entries].first[:user_id]
    assert_equal true, payload[:entries].first[:is_current_user]
  end

  test "fetch applies country scope" do
    us_user = create_user(username: "entries_us", country_code: "US")
    ca_user = create_user(username: "entries_ca", country_code: "CA")
    board = create_board
    board.entries.create!(user: us_user, total_seconds: 300, streak_count: 1)
    board.entries.create!(user: ca_user, total_seconds: 200, streak_count: 1)

    payload = LeaderboardEntries.fetch(leaderboard: board, scope: :country, country_code: "US")

    assert_equal 1, payload[:total]
    assert_equal [ us_user.id ], payload[:entries].map { |entry| entry[:user_id] }
  end

  test "fetch can include active project enrichment" do
    user = create_user(username: "entries_active")
    board = create_board
    board.entries.create!(user: user, total_seconds: 300, streak_count: 1)
    user.project_repo_mappings.create!(project_name: "active-project")
    Heartbeat.create!(
      user: user,
      project: "active-project",
      category: "coding",
      time: Time.current.to_f,
      source_type: :direct_entry
    )

    payload = LeaderboardEntries.fetch(leaderboard: board, include_active_projects: true)

    assert_equal({ name: "active-project", repo_url: nil }, payload[:entries].first[:active_project])
  end

  test "fetch_public uses lean public-visible entries" do
    hidden_user = create_user(username: "public_hidden", leaderboard_shadowbanned: true)
    visible_user = create_user(username: "public_visible", trust_level: :green)
    board = create_board
    board.entries.create!(user: hidden_user, total_seconds: 500, streak_count: 1)
    board.entries.create!(user: visible_user, total_seconds: 300, streak_count: 2)

    payload = LeaderboardEntries.fetch_public(leaderboard: board)

    assert_equal 1, payload[:total]
    assert_equal visible_user.id, payload[:entries].first[:user_id]
    assert_equal 1, payload[:entries].first[:rank]
    assert_equal visible_user.display_name, payload[:entries].first.dig(:user, :display_name)
  end

  test "fetch_public cache follows leaderboard page cache version" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache.lookup_store(:memory_store)
    Rails.cache.clear

    user = create_user(username: "public_cache_visible")
    board = create_board
    board.entries.create!(user: user, total_seconds: 300, streak_count: 1)

    assert_equal 1, LeaderboardEntries.fetch_public(leaderboard: board)[:total]

    user.set_leaderboard_shadowban(
      banned: true,
      changed_by_user: User.create!(timezone: "UTC", admin_level: :superadmin),
      reason: "test shadowban"
    )

    assert_equal 0, LeaderboardEntries.fetch_public(leaderboard: board)[:total]
  ensure
    Rails.cache.clear
    Rails.cache = original_cache
  end

  private

  def create_user(username:, country_code: nil, leaderboard_shadowbanned: false, trust_level: :blue)
    User.create!(
      username: username,
      country_code: country_code,
      timezone: "UTC",
      trust_level: trust_level,
      leaderboard_shadowbanned: leaderboard_shadowbanned,
      leaderboard_shadowban_reason: leaderboard_shadowbanned ? "test shadowban" : nil
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
end
