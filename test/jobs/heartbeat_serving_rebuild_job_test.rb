require "test_helper"

class HeartbeatServingRebuildJobTest < ActiveJob::TestCase
  test "rebuilds serving facts for each requested user" do
    first_user = User.create!(timezone: "UTC")
    second_user = User.create!(timezone: "UTC")
    base = Time.utc(2026, 7, 10, 12)
    create_project_heartbeats(first_user, "first", base, 60)
    create_project_heartbeats(second_user, "second", base, 90)
    clear_serving_tables

    HeartbeatServingRebuildJob.perform_now([ first_user.id, second_user.id ], reason: "test_rebuild")

    assert_equal 60, Clickhouse::HeartbeatProjectSummary.seconds_for(user_id: first_user.id, project: "first")
    assert_equal 90, Clickhouse::HeartbeatProjectSummary.seconds_for(user_id: second_user.id, project: "second")
    assert_equal [ "test_rebuild" ], Clickhouse::HeartbeatIntervalDelta.distinct.pluck(:reason)
  end

  private

  def create_project_heartbeats(user, project, base, duration)
    create_heartbeat(user: user, time: base.to_f, project: project, category: "coding", source_type: :test_entry)
    create_heartbeat(user: user, time: (base + duration.seconds).to_f, project: project, category: "coding", source_type: :test_entry)
  end

  def clear_serving_tables
    ClickhouseTestIsolation::SERVING_TABLES.each do |table|
      Clickhouse::Record.connection.execute("TRUNCATE TABLE #{table}")
    end
  end
end
