require "test_helper"

class Api::Admin::V1::AdminControllerTest < ActionDispatch::IntegrationTest
  test "quantized visualization uses the target user's calendar days across DST and month boundaries" do
    admin = create(:user, :superadmin)
    key = create(:admin_api_key, user: admin, name: "test")
    user = create(:user, timezone: "America/Los_Angeles")
    timezone = ActiveSupport::TimeZone[user.timezone]

    outside_start = timezone.local(2024, 2, 29, 23, 59, 30).to_i
    march_start = timezone.local(2024, 3, 1, 0, 0, 30).to_i
    before_local_midnight = timezone.local(2024, 3, 9, 23, 59, 30).to_i
    after_local_midnight = timezone.local(2024, 3, 10, 0, 0, 30).to_i
    before_dst_jump = timezone.local(2024, 3, 10, 1, 59, 30).to_i
    after_dst_jump = timezone.local(2024, 3, 10, 3, 0, 30).to_i
    march_end = timezone.local(2024, 3, 31, 23, 59, 30).to_i
    outside_end = timezone.local(2024, 4, 1, 0, 0, 30).to_i

    [
      outside_start,
      march_start,
      before_local_midnight,
      after_local_midnight,
      before_dst_jump,
      after_dst_jump,
      march_end,
      outside_end
    ].each { |time| create(:heartbeat, user: user, time: time) }

    get "/api/admin/v1/users/#{user.id}/visualization/quantized",
      params: { year: 2024, month: 3 }, headers: auth_headers(key)

    assert_response :success
    days = response.parsed_body.fetch("days")
    assert_equal 31, days.length
    assert_equal timezone.local(2024, 3, 1).to_i, days.first.fetch("date_timestamp_s")
    assert_equal timezone.local(2024, 3, 31).to_i, days.last.fetch("date_timestamp_s")
    assert_equal 23.hours.to_i,
      days[10].fetch("date_timestamp_s") - days[9].fetch("date_timestamp_s")

    assert_equal [ march_start ], days[0].fetch("points").pluck("time")
    assert_equal [ before_local_midnight ], days[8].fetch("points").pluck("time")
    assert_equal [ after_local_midnight, before_dst_jump, after_dst_jump ],
      days[9].fetch("points").pluck("time")
    assert_equal 180, days[9].fetch("total_seconds")
    assert_equal [ march_end ], days[30].fetch("points").pluck("time")
  end

  test "user heartbeats returns ja4 fingerprint and name" do
    admin = create(:user, :superadmin)
    key = create(:admin_api_key, user: admin, name: "test")
    user = create(:user, username: "admin_heartbeats_ja4")
    ja4 = create(:ja4, fingerprint: "t13d1312h2_f57a46bbacb6_ab7e3b40a677", name: "Go net/http")

    create(:heartbeat,
      user: user,
      time: Time.current.to_i,
      project: "test-project",
      entity: "test.rb",
      source_type: :direct_entry,
      ja4: ja4
    )

    get "/api/admin/v1/user/heartbeats", params: { user_id: user.id }, headers: auth_headers(key)

    assert_response :success
    response_ja4 = response.parsed_body.fetch("heartbeats").first.fetch("ja4")
    assert_equal "t13d1312h2_f57a46bbacb6_ab7e3b40a677", response_ja4.fetch("fingerprint")
    assert_equal "Go net/http", response_ja4.fetch("name")
  end

  private

  def auth_headers(key)
    { "Authorization" => ActionController::HttpAuthentication::Token.encode_credentials(key.token) }
  end
end
