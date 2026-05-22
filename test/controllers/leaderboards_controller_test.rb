require "test_helper"

class LeaderboardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
  end

  teardown do
    Rails.cache.clear
  end

  test "index renders with correct period_type and scope props" do
    us_user = create_user(username: "us_index_user", country_code: "US")
    create_boards_for_today(period_type: :last_7_days)

    sign_in_as(us_user)
    get leaderboards_path(period_type: "last_7_days", scope: "country")

    assert_response :success
    assert_inertia_component "Leaderboards/Index"
    assert_inertia_prop "period_type", "last_7_days"
    assert_inertia_prop "scope", "country"
    page = inertia_page
    assert_equal "US", page.dig("props", "country", "code")
    assert page.dig("props", "country", "available")
  end

  test "index falls back to global scope when country is missing" do
    viewer = create_user(username: "viewer_no_country")
    create_boards_for_today(period_type: :daily)

    sign_in_as(viewer)
    get leaderboards_path(period_type: "daily", scope: "country")

    assert_response :success
    assert_inertia_component "Leaderboards/Index"
    assert_inertia_prop "scope", "global"
    page = inertia_page
    assert_not page.dig("props", "country", "available")
  end

  test "index clamps invalid period_type to daily" do
    user = create_user(username: "bad_period_user2")
    create_boards_for_today(period_type: :daily)

    sign_in_as(user)
    get leaderboards_path(period_type: "bogus")

    assert_response :success
    assert_inertia_prop "period_type", "daily"
  end

  test "validated_period_type does not intern arbitrary symbols" do
    user = create_user(username: "bad_period_user")
    create_boards_for_today(period_type: :daily)

    sign_in_as(user)
    get leaderboards_path(period_type: "evil_user_input_xyz")

    assert_response :success
    assert_not Symbol.all_symbols.map(&:to_s).include?("evil_user_input_xyz"),
      "Arbitrary user input should not be interned as a symbol"
  end

  test "deferred entries hide leaderboard shadowbanned users from other viewers" do
    viewer = create_user(username: "lb_visible_viewer")
    visible_user = create_user(username: "lb_visible_user")
    hidden_user = create_user(username: "lb_hidden_user", leaderboard_shadowbanned: true)
    board = create_boards_for_today(period_type: :daily).first
    board.entries.create!(user: visible_user, total_seconds: 300, streak_count: 1)
    board.entries.create!(user: hidden_user, total_seconds: 200, streak_count: 1)

    sign_in_as(viewer)
    get leaderboards_path
    version = inertia_page["version"]

    get leaderboards_path, headers: inertia_partial_headers(version)

    assert_response :success
    entries_payload = JSON.parse(response.body).dig("props", "entries")
    assert_equal 2, entries_payload["total"]
    assert_equal [ visible_user.id ], entries_payload["entries"].map { |entry| entry["user_id"] }
    assert_nil entries_payload["entries"].first.dig("user", "shadowbanned")
  end

  test "deferred entries show leaderboard shadowbanned user to themselves" do
    hidden_user = create_user(username: "lb_hidden_self", leaderboard_shadowbanned: true)
    board = create_boards_for_today(period_type: :daily).first
    board.entries.create!(user: hidden_user, total_seconds: 200, streak_count: 1)

    sign_in_as(hidden_user)
    get leaderboards_path
    version = inertia_page["version"]

    get leaderboards_path, headers: inertia_partial_headers(version)

    assert_response :success
    entries_payload = JSON.parse(response.body).dig("props", "entries")
    assert_equal 1, entries_payload["total"]
    assert_equal hidden_user.id, entries_payload["entries"].first["user_id"]
    assert_equal true, entries_payload["entries"].first["is_current_user"]
  end

  private

  def create_user(username:, country_code: nil, leaderboard_shadowbanned: false)
    User.create!(
      username:,
      country_code:,
      timezone: "UTC",
      leaderboard_shadowbanned: leaderboard_shadowbanned,
      leaderboard_shadowban_reason: leaderboard_shadowbanned ? "test shadowban" : nil
    )
  end

  def create_boards_for_today(period_type:)
    [ Date.current, Time.current.in_time_zone("UTC").to_date ].uniq.map do |date|
      Leaderboard.create!(
        start_date: date,
        period_type: period_type,
        timezone_utc_offset: nil,
        finished_generating_at: Time.current
      )
    end
  end

  def inertia_partial_headers(version)
    {
      "X-Inertia" => "true",
      "X-Requested-With" => "XMLHttpRequest",
      "X-Inertia-Version" => version,
      "X-Inertia-Partial-Component" => "Leaderboards/Index",
      "X-Inertia-Partial-Data" => "entries"
    }
  end
end
