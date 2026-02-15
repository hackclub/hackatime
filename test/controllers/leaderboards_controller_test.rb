require "test_helper"

class LeaderboardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
  end

  teardown do
    Rails.cache.clear
  end

  test "index renders country tab label and preserves scope in period links" do
    us_user = create_user(username: "us_index_user", country_code: "US")
    create_boards_for_today(period_type: :last_7_days)

    sign_in_as(us_user)
    get leaderboards_path(period_type: "last_7_days", scope: "country")

    assert_response :success
    assert_select "a[href='#{leaderboards_path(period_type: "last_7_days", scope: "global")}']", text: "Global"
    assert_select "a[href='#{leaderboards_path(period_type: "last_7_days", scope: "country")}']", text: /United States/
    assert_select "a[href='#{leaderboards_path(period_type: "daily", scope: "country")}']", text: "Last 24 Hours"
  end

  test "index falls back to global selector state when country is missing" do
    viewer = create_user(username: "viewer_no_country")
    create_boards_for_today(period_type: :daily)

    sign_in_as(viewer)
    get leaderboards_path(period_type: "daily", scope: "country")

    assert_response :success
    assert_select "span", text: "Country"
    assert_select "a[href='#{leaderboards_path(period_type: "daily", scope: "global")}']"
  end

  test "entries clamps page=0 to page 1 instead of erroring" do
    user = create_user(username: "page_zero_user")
    board = create_boards_for_today(period_type: :daily).first
    board.entries.create!(user: user, total_seconds: 100)

    sign_in_as(user)
    get entries_leaderboards_path(period_type: "daily", page: 0), xhr: true

    assert_response :success
  end

  test "entries clamps negative page to page 1 instead of erroring" do
    user = create_user(username: "neg_page_user")
    board = create_boards_for_today(period_type: :daily).first
    board.entries.create!(user: user, total_seconds: 100)

    sign_in_as(user)
    get entries_leaderboards_path(period_type: "daily", page: -5), xhr: true

    assert_response :success
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

  def sign_in_as(user)
    token = user.sign_in_tokens.create!(auth_type: :email)
    get auth_token_path(token: token.token)
    assert_equal user.id, session[:user_id]
  end
end
