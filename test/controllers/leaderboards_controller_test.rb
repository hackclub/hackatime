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
    assert_inertia_props period_type: "last_7_days", scope: "country"
    assert_equal "US", inertia.props.dig("country", "code")
    assert inertia.props.dig("country", "available")
  end

  test "index falls back to global scope when country is missing" do
    viewer = create_user(username: "viewer_no_country")
    create_boards_for_today(period_type: :daily)

    sign_in_as(viewer)
    get leaderboards_path(period_type: "daily", scope: "country")

    assert_response :success
    assert_inertia_component "Leaderboards/Index"
    assert_inertia_props scope: "global"
    assert_not inertia.props.dig("country", "available")
  end

  test "index clamps invalid period_type to daily" do
    user = create_user(username: "bad_period_user2")
    create_boards_for_today(period_type: :daily)

    sign_in_as(user)
    get leaderboards_path(period_type: "bogus")

    assert_response :success
    assert_inertia_props period_type: "daily"
  end

  test "index exposes Telescreen links to admin-level viewers only" do
    create_boards_for_today(period_type: :daily)

    %i[admin superadmin ultraadmin].each do |admin_level|
      sign_in_as(create_user(username: "lb_#{admin_level}", admin_level: admin_level))
      get leaderboards_path
      assert_inertia_props can_view_telescreen: true
    end

    sign_in_as(create_user(username: "leaderboard_viewer", admin_level: :viewer))
    get leaderboards_path
    assert_inertia_props can_view_telescreen: false
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
    create(:leaderboard_entry, leaderboard: board, user: visible_user, total_seconds: 300, streak_count: 1)
    create(:leaderboard_entry, leaderboard: board, user: hidden_user, total_seconds: 200, streak_count: 1)

    sign_in_as(viewer)
    get leaderboards_path
    inertia_load_deferred_props :default

    assert_response :success
    entries_payload = inertia.props["entries"]
    assert_equal 1, entries_payload["total"]
    assert_equal [ visible_user.id ], entries_payload["entries"].map { |entry| entry["user_id"] }
    assert_nil entries_payload["entries"].first.dig("user", "shadowbanned")
  end

  test "deferred entries show leaderboard shadowbanned user to themselves" do
    hidden_user = create_user(username: "lb_hidden_self", leaderboard_shadowbanned: true)
    board = create_boards_for_today(period_type: :daily).first
    create(:leaderboard_entry, leaderboard: board, user: hidden_user, total_seconds: 200, streak_count: 1)

    sign_in_as(hidden_user)
    get leaderboards_path
    inertia_load_deferred_props :default

    assert_response :success
    entries_payload = inertia.props["entries"]
    assert_equal 1, entries_payload["total"]
    assert_equal hidden_user.id, entries_payload["entries"].first["user_id"]
    assert_equal true, entries_payload["entries"].first["is_current_user"]
  end

  private

  def create_user(username:, country_code: nil, leaderboard_shadowbanned: false, admin_level: :default)
    create(:user,
      username:,
      country_code:,
      admin_level:,
      leaderboard_shadowbanned: leaderboard_shadowbanned,
      leaderboard_shadowban_reason: leaderboard_shadowbanned ? "test shadowban" : nil
    )
  end

  def create_boards_for_today(period_type:)
    [ Date.current, Time.current.in_time_zone("UTC").to_date ].uniq.map do |date|
      create(:leaderboard,
        start_date: date,
        period_type: period_type,
        timezone_utc_offset: nil,
        finished_generating_at: Time.current
      )
    end
  end
end
