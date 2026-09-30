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

  test "admin heartbeat listings flag hidden heartbeats" do
    admin = create(:user, :superadmin)
    key = create(:admin_api_key, user: admin, name: "test")
    user = create(:user, username: "admin_hidden_flag", timezone: "UTC")
    time = 2.days.ago.utc.beginning_of_day + 12.hours
    kept, deleted = %w[kept deleted].each_with_index.map do |project, index|
      create(:heartbeat, user:, time: (time + index * 60).to_f, project:, entity: "#{project}.rb",
        source_type: :direct_entry, user_agent: "wakatime/flag-agent")
    end
    HeartbeatExclusion.create!(user:, kind: :project_deletion, project: "deleted")
    expected = { kept.id => false, deleted.id => true }

    get "/api/admin/v1/user/heartbeats", params: { user_id: user.id }, headers: auth_headers(key)
    assert_equal expected, hidden_by_id(response)

    get "/api/admin/v1/user/stats", params: { user_id: user.id, date: time.to_date.iso8601 }, headers: auth_headers(key)
    assert_equal expected, hidden_by_id(response)

    get "/api/admin/v1/heartbeats/by_user_agent_segment", params: { segment: "flag-agent" }, headers: auth_headers(key)
    assert_equal expected, hidden_by_id(response)
  end

  test "raw SQL admin queries flag hidden heartbeats" do
    admin = create(:user, :superadmin)
    key = create(:admin_api_key, user: admin, name: "test")
    poisoned = create(:user, username: "raw_flag_poisoned", timezone: "UTC")
    clean = create(:user, username: "raw_flag_clean", timezone: "UTC")
    time = 2.days.ago.utc.beginning_of_day + 12.hours
    [ poisoned, clean ].each do |user|
      create(:heartbeat, user:, time: time.to_f, project: "p", entity: "#{user.username}.rb", lineno: 1,
        source_type: :direct_entry, machine: "shared-machine", ip_address: "203.0.113.9")
    end
    poisoned.apply_poison!(Date.current.to_s)

    get "/api/admin/v1/users/#{poisoned.id}/visualization/quantized",
      params: { year: time.year, month: time.month }, headers: auth_headers(key)
    assert_response :success
    points = response.parsed_body.fetch("days").flat_map { |day| day.fetch("points") }
    assert_equal [ true ], points.map { |point| point.fetch("hidden") }

    [ "/api/admin/v1/heartbeats/ip_machine_pairs", "/api/admin/v1/alts/candidates" ].each do |path|
      get path, headers: auth_headers(key)
      assert_response :success
      row = response.parsed_body.values.first.find { |r| r.fetch("user_a_id") == [ poisoned.id, clean.id ].min }
      assert_equal poisoned.id < clean.id, row.fetch("user_a_hidden"), path
      assert_equal poisoned.id > clean.id, row.fetch("user_b_hidden"), path
    end

    get "/api/admin/v1/heartbeats/shared_machines", headers: auth_headers(key)
    assert_response :success
    machine = response.parsed_body.fetch("machines").find { |m| m.fetch("machine") == "shared-machine" }
    assert_equal "{#{[ poisoned.id, clean.id ].sort.join(',')}}", machine.fetch("user_ids")
    assert_equal "{#{poisoned.id}}", machine.fetch("hidden_user_ids")
  end

  private

  def hidden_by_id(response)
    assert_response :success
    response.parsed_body.fetch("heartbeats").to_h { |hb| [ hb.fetch("id"), hb.fetch("hidden") ] }
  end

  def auth_headers(key)
    { "Authorization" => ActionController::HttpAuthentication::Token.encode_credentials(key.token) }
  end
end
