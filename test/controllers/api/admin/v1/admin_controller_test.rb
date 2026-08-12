require "test_helper"

class Api::Admin::V1::AdminControllerTest < ActionDispatch::IntegrationTest
  class FakeClickHouseClient
    def initialize(results)
      @results = results
    end

    def select(*) = @results.shift
  end

  setup do
    admin = User.create!(timezone: "UTC", admin_level: :superadmin)
    @headers = auth_headers(admin.admin_api_keys.create!(name: "test"))
  end

  test "user heartbeats returns ja4 fingerprint and name" do
    user = User.create!(timezone: "UTC", username: "admin_heartbeats_ja4")
    ja4 = Ja4.create!(fingerprint: "t13d1312h2_f57a46bbacb6_ab7e3b40a677", name: "Go net/http")

    user.heartbeats.create!(
      time: Time.current.to_i,
      project: "test-project",
      entity: "test.rb",
      source_type: :direct_entry,
      ja4: ja4
    )

    get "/api/admin/v1/user/heartbeats", params: { user_id: user.id }, headers: @headers

    assert_response :success
    response_ja4 = response.parsed_body.fetch("heartbeats").first.fetch("ja4")
    assert_equal "t13d1312h2_f57a46bbacb6_ab7e3b40a677", response_ja4.fetch("fingerprint")
    assert_equal "Go net/http", response_ja4.fetch("name")
  end

  test "user heartbeats preserves PostgreSQL JSON types through ClickHouse plucks" do
    user = User.create!(timezone: "UTC", username: "admin_ch_types")
    row = Api::Admin::V1::UserUtilities::HEARTBEAT_RESPONSE_COLUMNS.index_with { nil }.transform_keys(&:to_s).merge(
      "id" => 42,
      "time" => 1_700_000_000.25,
      "created_at" => "2026-08-12 14:23:45.123456",
      "source_type" => 0,
      "ip_address" => "203.0.113.1",
      "is_write" => true,
      "dependencies" => [],
      "dependencies_is_null" => false
    )
    repository = HeartbeatRepository.new(client: FakeClickHouseClient.new([ [ { "value" => 1 } ], [ row ] ]))

    with_clickhouse_repository(repository) do
      get "/api/admin/v1/user/heartbeats", params: { user_id: user.id }, headers: @headers
    end

    assert_response :success
    heartbeat = response.parsed_body.fetch("heartbeats").sole
    assert_equal "2026-08-12T14:23:45.123Z", heartbeat.fetch("created_at")
    assert_equal "direct_entry", heartbeat.fetch("source_type")
    assert_equal "203.0.113.1", heartbeat.fetch("ip_address")
    assert_equal true, heartbeat.fetch("is_write")
  end

  test "user info renders normalized ClickHouse stats through the shared response" do
    user = User.create!(timezone: "UTC", username: "admin_info_clickhouse")
    repository = HeartbeatRepository.new(client: nil)
    stats = {
      "total_heartbeats" => 12,
      "total_coding_time" => 345,
      "languages_used" => 2,
      "projects_worked_on" => 3,
      "days_active" => 4,
      "last_heartbeat_at" => 1_700_000_000.25
    }
    repository.define_singleton_method(:normalized_user_stats) { |_| stats }

    with_clickhouse_repository(repository) do
      get "/api/admin/v1/user/info", params: { user_id: user.id }, headers: @headers
    end

    assert_response :success
    result = response.parsed_body.fetch("user")
    assert_equal 1_700_000_000.25, result.fetch("last_heartbeat_at")
    assert_equal stats.except("last_heartbeat_at"), result.fetch("stats")
  end

  test "user info preserves the PostgreSQL response through normalized shaping" do
    user = User.create!(timezone: "UTC", username: "admin_pg_info")
    user.heartbeats.create!(time: 1_700_000_000.25, project: "migration", language: "Ruby", source_type: :direct_entry)

    get "/api/admin/v1/user/info", params: { user_id: user.id }, headers: @headers

    assert_response :success
    result = response.parsed_body.fetch("user")
    assert_equal 1_700_000_000.25, result.fetch("last_heartbeat_at")
    assert_equal 1, result.dig("stats", "total_heartbeats")
    assert_equal 1, result.dig("stats", "languages_used")
    assert_equal 1, result.dig("stats", "projects_worked_on")
  end

  test "user projects renders normalized ClickHouse rows through the shared response" do
    user = User.create!(timezone: "UTC", username: "admin_ch_projects")
    mapping = user.project_repo_mappings.create!(project_name: "migration", archived_at: Time.current)
    repository = HeartbeatRepository.new(client: nil)
    stats = [ {
      "project" => "migration",
      "heartbeat_count" => 3,
      "duration" => 150,
      "first_heartbeat" => 1_700_000_000.25,
      "last_heartbeat" => 1_700_000_300.75,
      "languages" => [ "Ruby" ]
    } ]
    repository.define_singleton_method(:project_stats) { |_| stats }

    with_clickhouse_repository(repository) do
      get "/api/admin/v1/user/projects", params: { user_id: user.id }, headers: @headers
    end

    assert_response :success
    project = response.parsed_body.fetch("projects").sole
    assert_equal "migration", project.fetch("name")
    assert_equal 3, project.fetch("total_heartbeats")
    assert_equal 150, project.fetch("total_duration")
    assert_equal mapping.id, project.fetch("repo_mapping_id")
    assert project.fetch("archived")
  end

  test "user projects preserves PostgreSQL results with deterministic languages" do
    user = User.create!(timezone: "UTC", username: "admin_pg_projects")
    user.heartbeats.create!(time: 1_700_000_000.25, project: "migration", language: "Ruby", source_type: :direct_entry)
    user.heartbeats.create!(time: 1_700_000_030.25, project: "migration", language: "Go", source_type: :direct_entry)

    get "/api/admin/v1/user/projects", params: { user_id: user.id }, headers: @headers

    assert_response :success
    project = response.parsed_body.fetch("projects").sole
    assert_equal "migration", project.fetch("name")
    assert_equal 2, project.fetch("total_heartbeats")
    assert_equal [ "Go", "Ruby" ], project.fetch("languages")
  end

  test "alternate candidates preserve legacy timestamp names for ClickHouse rows" do
    repository = HeartbeatRepository.new(client: nil)
    arguments = nil
    candidates = [ {
      "user_a_id" => 1,
      "user_b_id" => 2,
      "user_a_first_seen" => 1_700_000_000.25,
      "user_a_last_seen" => 1_700_000_100.25,
      "user_b_first_seen" => 1_700_000_200.25,
      "user_b_last_seen" => 1_700_000_300.25
    } ]
    repository.define_singleton_method(:ip_machine_pairs) do |**keywords|
      arguments = keywords
      candidates
    end

    with_clickhouse_repository(repository) do
      get "/api/admin/v1/alts/candidates", headers: @headers
    end

    assert_response :success
    result = response.parsed_body.fetch("candidates").sole
    assert_equal true, arguments.fetch(:inclusive)
    assert_equal 1_700_000_000.25, result.fetch("user_a_first_seen_on_combo")
    assert_equal 1_700_000_300.25, result.fetch("user_b_last_seen_on_combo")
    assert_not result.key?("user_a_first_seen")
    assert_not result.key?("user_b_last_seen")
  end

  private

  def with_clickhouse_repository(repository)
    previous_repository = HeartbeatRepository.instance_variable_get(:@current)
    previous_test_setting = ENV["CLICKHOUSE_TEST"]
    HeartbeatRepository.instance_variable_set(:@current, repository)
    ENV["CLICKHOUSE_TEST"] = "1"
    yield
  ensure
    HeartbeatRepository.instance_variable_set(:@current, previous_repository)
    ENV["CLICKHOUSE_TEST"] = previous_test_setting
  end

  def auth_headers(key)
    { "Authorization" => ActionController::HttpAuthentication::Token.encode_credentials(key.token) }
  end
end
