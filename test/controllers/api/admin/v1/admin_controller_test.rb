require "test_helper"

class Api::Admin::V1::AdminControllerTest < ActionDispatch::IntegrationTest
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

  test "admin heartbeat reads include poisoned heartbeats" do
    admin = create(:user, :superadmin)
    key = create(:admin_api_key, user: admin, name: "test")
    user = create(:user, username: "admin_poisoned_reads", timezone: "UTC")
    start = 3.days.ago.utc.beginning_of_day + 12.hours
    hidden = [ 0, 60, 120 ].map do |offset|
      create(:heartbeat, user:, time: (start + offset).to_f, project: "faked", entity: "a.rb",
        category: "coding", source_type: :direct_entry, machine: "poisoned-machine", user_agent: "wakatime/poison-agent")
    end
    user.apply_poison!(Date.current.to_s)
    assert_empty user.heartbeats.reload

    get "/api/admin/v1/user/heartbeats", params: { user_id: user.id }, headers: auth_headers(key)
    assert_response :success
    assert_equal hidden.map(&:id), response.parsed_body.fetch("heartbeats").map { |hb| hb.fetch("id") }

    get "/api/admin/v1/user/info", params: { user_id: user.id }, headers: auth_headers(key)
    assert_response :success
    assert_equal 3, response.parsed_body.dig("user", "stats", "total_heartbeats")
    assert_equal 120, response.parsed_body.dig("user", "stats", "total_coding_time")

    get "/api/admin/v1/user/stats", params: { user_id: user.id, date: start.to_date.iso8601 }, headers: auth_headers(key)
    assert_response :success
    assert_equal 120, response.parsed_body.fetch("total_duration")

    get "/api/admin/v1/user/projects", params: { user_id: user.id }, headers: auth_headers(key)
    assert_response :success
    assert_equal [ "faked" ], response.parsed_body.fetch("projects").map { |project| project.fetch("name") }

    get "/api/admin/v1/user/get_users_by_machine", params: { machine: "poisoned-machine" }, headers: auth_headers(key)
    assert_response :success
    assert_equal [ user.id ], response.parsed_body.fetch("users").map { |row| row.fetch("user_id") }

    get "/api/admin/v1/heartbeats/by_user_agent_segment", params: { segment: "poison-agent", count_only: true }, headers: auth_headers(key)
    assert_response :success
    assert_equal 3, response.parsed_body.fetch("total_count")

    get "/api/admin/v1/timeline", params: { date: start.to_date.iso8601, user_ids: user.id.to_s }, headers: auth_headers(key)
    assert_response :success
    timeline = response.parsed_body.fetch("users").find { |entry| entry.dig("user", "id") == user.id }
    assert_equal 120, timeline.fetch("total_coded_time")
  end

  private

  def auth_headers(key)
    { "Authorization" => ActionController::HttpAuthentication::Token.encode_credentials(key.token) }
  end
end
