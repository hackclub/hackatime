require "test_helper"

class HeartbeatServingRebuildJobTest < ActiveJob::TestCase
  class RejectingQueueAdapter
    def enqueue(_job) = raise ActiveJob::EnqueueError, "queue unavailable"
    def enqueue_at(_job, _timestamp) = raise ActiveJob::EnqueueError, "queue unavailable"
  end

  setup do
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
  end

  teardown do
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

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

  test "corrects both users after an account merge" do
    older_user = User.create!(timezone: "UTC")
    newer_user = User.create!(timezone: "UTC")
    base = Time.utc(2026, 7, 10, 12)
    create_project_heartbeats(older_user, "merged", base, 60)
    create_project_heartbeats(newer_user, "merged", base + 2.minutes, 60)

    perform_enqueued_jobs do
      Clickhouse::HeartbeatWriter.merge_user_heartbeats!(
        older_user_id: older_user.id,
        newer_user_id: newer_user.id
      )
    end

    assert_equal 180, Clickhouse::StatsReader.new(older_user).project_seconds("merged")
    assert_equal 0, Clickhouse::StatsReader.new(newer_user).project_seconds("merged")
    assert_empty Clickhouse::Heartbeat.for_user(newer_user)
  end

  test "rebuilds synchronously when an account merge cannot enqueue its correction" do
    older_user = User.create!(timezone: "UTC")
    newer_user = User.create!(timezone: "UTC")
    base = Time.utc(2026, 7, 10, 12)
    create_project_heartbeats(older_user, "merged", base, 60)
    create_project_heartbeats(newer_user, "merged", base + 2.minutes, 60)
    ActiveJob::Base.queue_adapter = RejectingQueueAdapter.new

    Clickhouse::HeartbeatWriter.merge_user_heartbeats!(
      older_user_id: older_user.id,
      newer_user_id: newer_user.id
    )

    assert_equal 180, Clickhouse::StatsReader.new(older_user).project_seconds("merged")
    assert_equal 0, Clickhouse::StatsReader.new(newer_user).project_seconds("merged")
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
