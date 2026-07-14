require "test_helper"

class HeartbeatServingRebuildJobTest < ActiveJob::TestCase
  test "rebuilds serving facts for each requested user" do
    first_user = User.create!(timezone: "UTC")
    second_user = User.create!(timezone: "UTC")
    base = Time.utc(2026, 7, 10, 12)
    create_project_heartbeats(first_user, "first", base, 60)
    create_project_heartbeats(second_user, "second", base, 90)
    clear_serving_tables

    HeartbeatServingRebuildJob.perform_now(
      [ first_user.id.to_s, second_user.id, first_user.id ],
      reason: "serving_backfill"
    )

    assert_equal 60, Clickhouse::StatsReader.new(first_user).project_seconds("first")
    assert_equal 90, Clickhouse::StatsReader.new(second_user).project_seconds("second")
    assert_equal [ "serving_backfill" ], Clickhouse::HeartbeatIntervalDelta.distinct.pluck(:reason)
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
