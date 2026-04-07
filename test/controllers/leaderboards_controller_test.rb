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

  test "gitlab-linked users are treated as qualified for leaderboard prompts" do
    user = User.create!(username: "gitlab_lb_user", gitlab_uid: "gl_123", timezone: "UTC")
    create_boards_for_today(period_type: :daily)

    sign_in_as(user)
    get leaderboards_path(period_type: "daily")

    assert_response :success
    assert_equal false, inertia_page.dig("props", "repo_host_account_blank")
  end

  private

  def create_user(username:, country_code: nil)
    User.create!(username:, country_code:, timezone: "UTC")
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
end
