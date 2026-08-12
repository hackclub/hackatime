require "test_helper"

class Cache::ActiveProjectsJobTest < ActiveSupport::TestCase
  setup { Rails.cache.clear }
  teardown { Rails.cache.clear }

  def create_heartbeat(user:, project:, **attrs)
    Heartbeat.create!(
      user: user, project: project, entity: "src/#{project}.rb",
      source_type: :direct_entry, time: Time.current.to_f, **attrs
    )
  end

  test "returns the most recent active project per user and excludes soft-deleted heartbeats" do
    user = User.create!(timezone: "UTC")
    ProjectRepoMapping.create!(user: user, project_name: "live")
    ProjectRepoMapping.create!(user: user, project_name: "ghost")

    create_heartbeat(user: user, project: "live", time: 1.minute.ago.to_f)
    # a soft-deleted recent heartbeat must NOT resurrect "ghost" as active
    create_heartbeat(user: user, project: "ghost", time: 30.seconds.ago.to_f, deleted_at: Time.current)

    result = Cache::ActiveProjectsJob.new.send(:calculate)

    assert_equal [ user.id ], result.keys
    assert_equal "live", result[user.id].project_name
  end

  test "excludes heartbeats older than the recent window and non-direct source types" do
    user = User.create!(timezone: "UTC")
    ProjectRepoMapping.create!(user: user, project_name: "stale")
    ProjectRepoMapping.create!(user: user, project_name: "imported")

    create_heartbeat(user: user, project: "stale", time: 10.minutes.ago.to_f)
    create_heartbeat(user: user, project: "imported", time: 1.minute.ago.to_f, source_type: :wakapi_import)

    assert_empty Cache::ActiveProjectsJob.new.send(:calculate)
  end

  test "ClickHouse chooses the latest project that has an active mapping" do
    user = User.create!(timezone: "UTC")
    mapping = ProjectRepoMapping.create!(user:, project_name: "mapped")
    repository = Object.new
    repository.define_singleton_method(:latest_direct_heartbeats) do |since:, coding_only:, per_project:|
      raise unless since && !coding_only && per_project

      [
        { "user_id" => user.id, "project" => "mapped", "latest_time" => 100.0, "latest_id" => 1 },
        { "user_id" => user.id, "project" => "unmapped", "latest_time" => 200.0, "latest_id" => 2 }
      ]
    end
    previous = ENV["CLICKHOUSE_TEST"]
    previous_repository = HeartbeatRepository.instance_variable_get(:@current)
    ENV["CLICKHOUSE_TEST"] = "1"
    HeartbeatRepository.instance_variable_set(:@current, repository)

    assert_equal({ user.id => mapping }, Cache::ActiveProjectsJob.new.send(:calculate))
  ensure
    ENV["CLICKHOUSE_TEST"] = previous
    HeartbeatRepository.instance_variable_set(:@current, previous_repository)
  end
end
