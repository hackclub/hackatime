require "test_helper"

class HeartbeatAccountMergeJobTest < ActiveJob::TestCase
  setup do
    @older_user = User.create!(timezone: "UTC")
    @newer_user = User.create!(timezone: "UTC")
    @base = Time.utc(2026, 7, 10, 12)
    @imported_version = (Time.current.to_r * 1_000_000_000).to_i - 1_000_000
  end

  test "GoodJob enqueue participates in a requires_new transaction" do
    original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :good_job
    active_job_id = nil

    assert_not GoodJob.configuration.enqueue_after_transaction_commit
    ActiveRecord::Base.transaction(requires_new: true) do
      job = HeartbeatAccountMergeJob.perform_later(
        older_user_id: @older_user.id,
        newer_user_id: @newer_user.id
      )
      active_job_id = job.job_id
      assert GoodJob::Job.exists?(active_job_id: active_job_id)
      raise ActiveRecord::Rollback
    end

    assert_not GoodJob::Job.exists?(active_job_id: active_job_id)
  ensure
    ActiveJob::Base.queue_adapter = original_queue_adapter if original_queue_adapter
  end

  test "moves production-scale imported versions and rebuilds serving facts" do
    create_project_heartbeats(@older_user, start_time: @base, duration: 60)
    create_project_heartbeats(
      @newer_user, start_time: @base + 2.minutes, duration: 60, version: @imported_version
    )

    HeartbeatAccountMergeJob.perform_now(
      older_user_id: @older_user.id,
      newer_user_id: @newer_user.id
    )

    winning_rows = Clickhouse::Heartbeat.with_deleted.for_user(@newer_user).pluck(:version, :deleted_at)
    assert_equal 2, winning_rows.size
    assert winning_rows.all? { |version, deleted_at| version > @imported_version + 1 && deleted_at.present? }
    assert_merge_converged(expected_seconds: 180)
  end

  test "is idempotent when performed twice" do
    create_project_heartbeats(@older_user, start_time: @base, duration: 60)
    create_project_heartbeats(
      @newer_user, start_time: @base + 2.minutes, duration: 60, version: @imported_version
    )

    2.times do
      HeartbeatAccountMergeJob.perform_now(
        older_user_id: @older_user.id,
        newer_user_id: @newer_user.id
      )
    end

    assert_merge_converged(expected_seconds: 180)
  end

  test "retry converges after copy succeeds and tombstoning fails" do
    create_project_heartbeats(@older_user, start_time: @base, duration: 60)
    create_project_heartbeats(@newer_user, start_time: @base + 2.minutes, duration: 60)
    connection = Clickhouse::Heartbeat.connection
    original_execute = connection.method(:execute)
    merge_insert_count = 0
    execute_with_tombstone_failure = lambda do |sql, *args, **kwargs|
      if sql.start_with?("INSERT INTO heartbeats") && sql.include?("FROM heartbeats FINAL")
        merge_insert_count += 1
        raise "tombstone failed" if merge_insert_count == 2
      end
      original_execute.call(sql, *args, **kwargs)
    end

    assert_raises(RuntimeError, "writer exceptions must escape for the job retry") do
      with_singleton_method(connection, :execute, execute_with_tombstone_failure) do
        Clickhouse::HeartbeatWriter.merge_user_heartbeats!(
          older_user_id: @older_user.id,
          newer_user_id: @newer_user.id
        )
      end
    end

    HeartbeatAccountMergeJob.perform_now(
      older_user_id: @older_user.id,
      newer_user_id: @newer_user.id
    )
    assert_merge_converged(expected_seconds: 180)
  end

  test "retry converges after the first user rebuild succeeds" do
    create_project_heartbeats(@older_user, start_time: @base, duration: 60)
    create_project_heartbeats(@newer_user, start_time: @base + 2.minutes, duration: 60)
    original_call = HeartbeatIntervals::UserRebuilder.method(:call)
    rebuild_count = 0
    call_with_failure_after_first_rebuild = lambda do |**kwargs|
      result = original_call.call(**kwargs)
      rebuild_count += 1
      raise "second rebuild unavailable" if rebuild_count == 1

      result
    end

    assert_raises(RuntimeError, "writer exceptions must escape for the job retry") do
      with_singleton_method(HeartbeatIntervals::UserRebuilder, :call, call_with_failure_after_first_rebuild) do
        Clickhouse::HeartbeatWriter.merge_user_heartbeats!(
          older_user_id: @older_user.id,
          newer_user_id: @newer_user.id
        )
      end
    end

    HeartbeatAccountMergeJob.perform_now(
      older_user_id: @older_user.id,
      newer_user_id: @newer_user.id
    )
    assert_merge_converged(expected_seconds: 180)
  end

  test "raises the final error after ten attempts" do
    job = HeartbeatAccountMergeJob.new(
      older_user_id: @older_user.id,
      newer_user_id: @newer_user.id
    )
    job.exception_executions = { [ StandardError ].to_s => 9 }
    failing_merge = ->(**) { raise "merge unavailable" }

    error = assert_raises(RuntimeError) do
      with_singleton_method(Clickhouse::HeartbeatWriter, :merge_user_heartbeats!, failing_merge) do
        job.perform_now
      end
    end
    assert_equal "merge unavailable", error.message
  end

  private

  def with_singleton_method(object, method_name, replacement)
    singleton_class = object.singleton_class
    original_method = object.method(method_name)
    singleton_class.define_method(method_name, replacement)
    yield
  ensure
    singleton_class&.define_method(method_name, original_method) if original_method
  end

  def create_project_heartbeats(user, start_time:, duration:, version: nil)
    create_heartbeat(
      user: user, time: start_time.to_f, project: "merged", category: "coding",
      source_type: :test_entry, version: version
    )
    create_heartbeat(
      user: user, time: (start_time + duration.seconds).to_f, project: "merged",
      category: "coding", source_type: :test_entry, version: version && version + 1
    )
  end

  def assert_merge_converged(expected_seconds:)
    assert_equal 4, Clickhouse::Heartbeat.for_user(@older_user).count
    assert_empty Clickhouse::Heartbeat.for_user(@newer_user)
    assert_equal expected_seconds, Clickhouse::Heartbeat.for_user(@older_user).duration_seconds
    assert_equal expected_seconds, Clickhouse::StatsReader.new(@older_user).project_seconds("merged")
    assert_equal 0, Clickhouse::StatsReader.new(@newer_user).project_seconds("merged")
  end
end
