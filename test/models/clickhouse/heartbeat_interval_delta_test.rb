require "test_helper"

class Clickhouse::HeartbeatIntervalDeltaTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

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

  test "inserted deltas fan out to ClickHouse serving tables" do
    now = Time.zone.local(2026, 7, 10, 12)

    Clickhouse::HeartbeatIntervalDelta.insert_all([
      {
        delta_id: Clickhouse::HeartbeatWriter.generate_id(now),
        user_id: 123,
        day: now.to_date,
        time: now.to_f,
        project: "hackatime",
        language: "Ruby",
        editor: "vscode",
        operating_system: "macOS",
        machine: "devbox",
        category: "coding",
        entity: "app/models/user.rb",
        branch: "main",
        user_seconds_delta: 90,
        project_seconds_delta: 80,
        language_seconds_delta: 70,
        editor_seconds_delta: 60,
        operating_system_seconds_delta: 50,
        machine_seconds_delta: 45,
        category_seconds_delta: 40,
        entity_seconds_delta: 30,
        branch_seconds_delta: 20,
        heartbeat_count_delta: 1,
        reason: "test",
        created_at: now
      }
    ])

    reader = Clickhouse::StatsReader.new(123)
    range = { start_time: now.beginning_of_day, end_time: now.end_of_day }
    assert_equal 90, reader.total_seconds(**range)
    assert_equal 80, reader.total_seconds(**range, filters: { project: "hackatime" })
    assert_equal 70, reader.total_seconds(**range, filters: { language: "Ruby" })
    assert_equal 60, reader.total_seconds(**range, filters: { editor: "vscode" })
    assert_equal 45, reader.total_seconds(**range, filters: { machine: "devbox" })
    assert_equal(
      { "Ruby" => 80 },
      reader.project_dimension_durations(
        project: "hackatime",
        dimension: "language",
        **range
      )
    )
    assert_equal 80, reader.project_seconds("hackatime")
  end

  test "rounds negative fractional correction facts once at the Ruby boundary" do
    now = Time.utc(2026, 7, 14, 12)
    Clickhouse::HeartbeatIntervalDelta.insert_all([
      {
        delta_id: Clickhouse::HeartbeatWriter.generate_id(now),
        user_id: 123,
        day: now.to_date,
        time: now.to_f,
        project: "corrected",
        language: "Ruby",
        editor: "vscode",
        operating_system: "macOS",
        machine: "devbox",
        category: "coding",
        entity: "app/corrected.rb",
        branch: "main",
        user_seconds_delta: -84.5,
        project_seconds_delta: -84.5,
        language_seconds_delta: -84.5,
        editor_seconds_delta: -84.5,
        operating_system_seconds_delta: -84.5,
        machine_seconds_delta: -84.5,
        category_seconds_delta: -84.5,
        entity_seconds_delta: -84.5,
        branch_seconds_delta: -84.5,
        heartbeat_count_delta: -1,
        reason: "negative_correction",
        created_at: now
      }
    ])

    reader = Clickhouse::StatsReader.new(123)
    assert_equal(-85, reader.project_seconds("corrected"))
    assert_equal({ "corrected" => -85 }, reader.project_durations)
  end

  test "heartbeat writer emits interval deltas for appended heartbeats" do
    user = User.create!(timezone: "UTC")
    base = Time.zone.local(2026, 7, 10, 12)

    create_heartbeat(
      user: user,
      time: base.to_f,
      project: "serving",
      language: "Ruby",
      editor: "vscode",
      operating_system: "macOS",
      machine: "devbox",
      category: "coding",
      entity: "app/a.rb",
      branch: "main",
      source_type: :test_entry
    )
    create_heartbeat(
      user: user,
      time: (base + 60.seconds).to_f,
      project: "serving",
      language: "Ruby",
      editor: "vscode",
      operating_system: "macOS",
      machine: "devbox",
      category: "coding",
      entity: "app/b.rb",
      branch: "main",
      source_type: :test_entry
    )

    range = { start_time: base.beginning_of_day, end_time: base.end_of_day }
    reader = Clickhouse::StatsReader.new(user)
    assert_equal 60, reader.total_seconds(**range)
    assert_equal 60, reader.total_seconds(**range, filters: { project: "serving" })
    assert_equal 60, reader.total_seconds(**range, filters: { language: "Ruby" })
    assert_equal 60, reader.total_seconds(**range, filters: { machine: "devbox" })
    assert_equal(
      { "Ruby" => 60 },
      reader.project_dimension_durations(project: "serving", dimension: "language", **range)
    )
    assert_equal 60, reader.project_seconds("serving")
  end

  test "appended intervals keep nil and blank project partitions distinct" do
    user = User.create!(timezone: "UTC")
    base = Time.utc(2026, 7, 14, 12)

    [ [ 0, nil ], [ 30, "" ], [ 60, nil ], [ 90, "" ] ].each do |offset, project|
      create_heartbeat(
        user:, time: (base + offset.seconds).to_f, project: project,
        category: "coding", source_type: :test_entry
      )
    end

    project_deltas = Clickhouse::HeartbeatIntervalDelta.where(user_id: user.id)
      .group(:project).sum(:project_seconds_delta).transform_values { |seconds| seconds.to_f.round }
    assert_equal({ HeartbeatIntervals::NULL_DIMENSION_VALUE => 60, "" => 60 }, project_deltas)
    assert_equal({ nil => 60, "" => 60 }, Clickhouse::StatsReader.new(user).project_durations)
  end

  test "rebuild converges legacy coalesced project facts and is idempotent" do
    user = User.create!(timezone: "UTC")
    base = Time.utc(2026, 7, 14, 12)
    sequence = [ [ 0, nil ], [ 30, "" ], [ 60, nil ], [ 90, "" ] ]
    rows = sequence.map.with_index do |(offset, project), index|
      {
        user_id: user.id,
        time: (base + offset.seconds).to_f,
        project: project,
        language: "Ruby",
        category: "coding",
        entity: "fixture_#{index}.rb",
        source_type: :test_entry
      }
    end
    Clickhouse::HeartbeatWriter.insert_rows(rows, maintain_serving_tables: false)
    insert_legacy_project_deltas(user.id, base, sequence)
    reader = Clickhouse::StatsReader.new(user)
    assert_equal({ "" => 90 }, reader.project_durations)

    HeartbeatIntervals::UserRebuilder.call(user_id: user.id, reason: "correct_legacy_project_encoding")
    raw = Clickhouse::Heartbeat.for_user(user).group(:project).duration_seconds
    assert_equal({ nil => 60, "" => 60 }, raw)
    assert_equal raw, reader.project_durations

    delta_count = Clickhouse::HeartbeatIntervalDelta.where(user_id: user.id).count
    HeartbeatIntervals::UserRebuilder.call(user_id: user.id, reason: "verify_project_encoding_idempotency")
    assert_equal delta_count, Clickhouse::HeartbeatIntervalDelta.where(user_id: user.id).count
    assert_equal raw, reader.project_durations
  end

  test "appended intervals ignore invalid predecessor timestamps" do
    user = User.create!(timezone: "UTC")
    base = Time.utc(2026, 7, 10, 12)

    create_heartbeat(user: user, time: -1, project: "valid", category: "coding", source_type: :test_entry)
    create_heartbeat(user: user, time: base.to_f, project: "valid", category: "coding", source_type: :test_entry)
    create_heartbeat(user: user, time: (base + 60.seconds).to_f, project: "valid", category: "coding", source_type: :test_entry)

    assert_equal 60, Clickhouse::StatsReader.new(user).project_seconds("valid")
    assert_equal Clickhouse::Heartbeat.for_user(user).where(project: "valid").duration_seconds,
      Clickhouse::StatsReader.new(user).project_seconds("valid")
  end

  test "bulk appends load dimension predecessors in one heartbeat query" do
    user = User.create!(timezone: "UTC")
    base = Time.utc(2026, 7, 10, 12)
    create_heartbeat(
      user: user, time: base.to_f, project: "bulk-0", language: "Ruby",
      editor: "vscode", category: "coding", source_type: :test_entry
    )
    rows = 20.times.map do |index|
      {
        user_id: user.id,
        time: (base + index + 1).to_f,
        project: "bulk-#{index % 4}",
        language: index.even? ? "Ruby" : "Python",
        editor: "vscode",
        category: "coding",
        source_type: :test_entry
      }
    end
    heartbeat_reads = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      heartbeat_reads += 1 if payload[:sql].to_s.match?(/\bFROM\s+heartbeats\b/i)
    end

    Clickhouse::HeartbeatWriter.insert_rows(rows)

    assert_operator heartbeat_reads, :<=, 3
    assert_equal Clickhouse::Heartbeat.for_user(user).duration_seconds,
      Clickhouse::StatsReader.new(user).total_seconds
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "single appends load all predecessors in one heartbeat query" do
    user = User.create!(timezone: "UTC")
    base = Time.utc(2026, 7, 10, 12)
    create_heartbeat(
      user: user, time: base.to_f, project: "single", language: "Ruby",
      editor: "vscode", operating_system: "macOS", machine: "devbox",
      category: "coding", entity: "app/first.rb", branch: "main", source_type: :test_entry
    )

    predecessor_reads = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      sql = payload[:sql].to_s
      predecessor_reads += 1 if sql.match?(/\bFROM\s+heartbeats\s+FINAL\b/i) && sql.include?("partition_value")
    end

    create_heartbeat(
      user: user, time: (base + 60.seconds).to_f, project: "single", language: "Ruby",
      editor: "vscode", operating_system: "macOS", machine: "devbox",
      category: "coding", entity: "app/second.rb", branch: "main", source_type: :test_entry
    )

    assert_equal 1, predecessor_reads
    assert_equal 60, Clickhouse::StatsReader.new(user).total_seconds
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "bulk soft delete supersedes production-scale versions and rebuilds serving totals" do
    user = User.create!(timezone: "UTC")
    base = Time.zone.local(2026, 7, 10, 12)
    imported_version = (Time.current.to_r * 1_000_000_000).to_i - 1_000_000

    create_heartbeat(
      user: user, time: base.to_f, project: "deleted", language: "Ruby",
      category: "coding", source_type: :test_entry, version: imported_version
    )
    create_heartbeat(
      user: user, time: (base + 60.seconds).to_f, project: "deleted", language: "Ruby",
      category: "coding", source_type: :test_entry, version: imported_version + 1
    )
    day = base.to_date

    assert_equal 2, Clickhouse::Heartbeat.for_user(user).count
    assert_equal 60, Clickhouse::StatsReader.new(user).total_seconds(start_time: day, end_time: day + 1.day)

    Clickhouse::HeartbeatWriter.soft_delete_user_heartbeats!(user.id)

    winning_rows = Clickhouse::Heartbeat.with_deleted.for_user(user).pluck(:version, :deleted_at)
    assert_equal 2, winning_rows.size
    assert winning_rows.all? { |version, deleted_at| version > imported_version + 1 && deleted_at.present? }
    assert_empty Clickhouse::Heartbeat.for_user(user)
    assert_equal 0, Clickhouse::StatsReader.new(user).total_seconds(start_time: day, end_time: day + 1.day)
    assert_equal 0, Clickhouse::StatsReader.new(user).project_seconds("deleted")
  end

  test "import rebuild corrects out of order interval deltas" do
    user = User.create!(timezone: "UTC")
    base = Time.zone.local(2026, 7, 10, 12)
    day = base.to_date

    create_heartbeat(user: user, time: base.to_f, project: "imported", language: "Ruby", category: "coding", source_type: :test_entry)
    create_heartbeat(user: user, time: (base + 120.seconds).to_f, project: "imported", language: "Ruby", category: "coding", source_type: :test_entry)

    assert_equal 120, Clickhouse::StatsReader.new(user).total_seconds(start_time: day, end_time: day + 1.day)

    HeartbeatIngest.call(
      user: user,
      mode: :import,
      heartbeats: [
        {
          time: (base + 60.seconds).to_f,
          entity: "app/imported.rb",
          project: "imported",
          language: "Ruby",
          category: "coding",
          type: "file"
        }
      ]
    )

    assert_equal 120, Clickhouse::StatsReader.new(user).total_seconds(start_time: day, end_time: day + 1.day)
    assert_equal 120, Clickhouse::StatsReader.new(user).project_seconds("imported")
  end

  test "direct late heartbeat rebuilds the affected user intervals" do
    user = User.create!(timezone: "UTC")
    base = Time.zone.local(2026, 7, 10, 12)
    day = base.to_date

    create_heartbeat(user: user, time: base.to_f, project: "late", language: "Ruby", category: "coding", source_type: :test_entry)
    create_heartbeat(user: user, time: (base + 120.seconds).to_f, project: "late", language: "Ruby", category: "coding", source_type: :test_entry)
    create_heartbeat(user: user, time: (base + 60.seconds).to_f, project: "late", language: "Python", category: "coding", source_type: :test_entry)

    assert_equal 120, Clickhouse::StatsReader.new(user).total_seconds(start_time: day, end_time: day + 1.day)
    assert_equal({ "Ruby" => 60, "Python" => 60 }, Clickhouse::StatsReader.new(user).dimension_durations(
      dimension: :language, start_time: day, end_time: day + 1.day
    ))
  end

  test "same timestamp insert rebuilds attribution when its id changes tie order" do
    user = User.create!(timezone: "UTC")
    base = Time.utc(2026, 7, 10, 12)
    day = base.to_date

    create_heartbeat(
      user: user, id: 10, time: base.to_f, project: "ties",
      language: "Ruby", category: "coding", source_type: :test_entry
    )
    create_heartbeat(
      user: user, id: 30, time: (base + 60.seconds).to_f, project: "ties",
      language: "Ruby", category: "coding", source_type: :test_entry
    )
    create_heartbeat(
      user: user, id: 20, time: (base + 60.seconds).to_f, project: "ties",
      language: "Python", category: "coding", source_type: :test_entry
    )

    range = { start_time: day, end_time: day + 1.day }
    raw = Clickhouse::Heartbeat.attributed_durations_by(Clickhouse::Heartbeat.for_user(user), :language)
    serving = Clickhouse::StatsReader.new(user).dimension_durations(dimension: :language, **range)

    assert_equal({ "Python" => 60, "Ruby" => 0 }, raw)
    assert_equal raw, serving
  end

  test "retrying an identical heartbeat does not duplicate serving deltas" do
    user = User.create!(timezone: "UTC")
    base = Time.zone.local(2026, 7, 10, 12)
    day = base.to_date

    create_heartbeat(user: user, time: base.to_f, project: "retry", category: "coding", source_type: :test_entry)
    heartbeat = create_heartbeat(user: user, time: (base + 60.seconds).to_f, project: "retry", category: "coding", source_type: :test_entry)
    delta_count = Clickhouse::HeartbeatIntervalDelta.where(user_id: user.id).count

    Clickhouse::HeartbeatWriter.insert_rows([
      heartbeat.attributes.slice(*Clickhouse::HeartbeatWriter::WRITABLE_COLUMNS)
    ])

    assert_equal delta_count, Clickhouse::HeartbeatIntervalDelta.where(user_id: user.id).count
    assert_equal 60, Clickhouse::StatsReader.new(user).total_seconds(start_time: day, end_time: day + 1.day)
  end

  test "enqueues one recovery when canonical insert succeeds before delta maintenance fails" do
    user = User.create!(timezone: "UTC")
    attrs = {
      user_id: user.id,
      time: Time.utc(2026, 7, 10, 12).to_f,
      project: "recovery",
      language: "Ruby",
      category: "coding",
      source_type: :test_entry
    }

    assert_enqueued_jobs 1, only: HeartbeatServingRebuildJob do
      assert_enqueued_with(
        job: HeartbeatServingRebuildJob,
        args: [ [ user.id ], { reason: "heartbeat_write_recovery" } ]
      ) do
        with_singleton_method(HeartbeatIntervals::DeltaWriter, :emit_for_inserted_rows, ->(*) { raise "delta write failed" }) do
          error = assert_raises(RuntimeError) do
            Clickhouse::HeartbeatWriter.insert_rows([ attrs ])
          end
          assert_equal "delta write failed", error.message
        end
      end
    end

    assert_equal 1, Clickhouse::Heartbeat.for_user(user).count
    assert_equal 0, Clickhouse::StatsReader.new(user).project_heartbeat_count("recovery")
  end

  test "rebuilds synchronously when serving recovery cannot be enqueued" do
    user = User.create!(timezone: "UTC")
    base = Time.utc(2026, 7, 10, 12)
    create_heartbeat(user: user, time: base.to_f, project: "recovery", category: "coding", source_type: :test_entry)
    ActiveJob::Base.queue_adapter = RejectingQueueAdapter.new

    maintenance_error = RuntimeError.new("delta write failed")
    with_singleton_method(HeartbeatIntervals::DeltaWriter, :emit_for_inserted_rows, ->(*) { raise maintenance_error }) do
      error = assert_raises(RuntimeError) do
        create_heartbeat(
          user: user,
          time: (base + 60.seconds).to_f,
          project: "recovery",
          category: "coding",
          source_type: :test_entry
        )
      end
      assert_same maintenance_error, error
    end

    assert_equal 2, Clickhouse::Heartbeat.for_user(user).count
    assert_equal 60, Clickhouse::StatsReader.new(user).project_seconds("recovery")
    assert_equal 2, Clickhouse::StatsReader.new(user).project_heartbeat_count("recovery")
    assert_includes Clickhouse::HeartbeatIntervalDelta.distinct.pluck(:reason), "heartbeat_write_recovery_synchronous"
  end

  test "raises complete recovery context when enqueue and synchronous rebuild fail" do
    user = User.create!(timezone: "UTC")
    attrs = {
      user_id: user.id,
      time: Time.utc(2026, 7, 10, 12).to_f,
      project: "unrepaired",
      category: "coding",
      source_type: :test_entry
    }
    ActiveJob::Base.queue_adapter = RejectingQueueAdapter.new
    maintenance_error = RuntimeError.new("delta write failed")
    rebuild_error = RuntimeError.new("synchronous rebuild failed")
    reports = []

    with_singleton_method(Rails.error, :report, ->(error, **options) { reports << [ error, options ] }) do
      with_singleton_method(HeartbeatIntervals::DeltaWriter, :emit_for_inserted_rows, ->(*) { raise maintenance_error }) do
        with_singleton_method(HeartbeatIntervals::UserRebuilder, :call, ->(**) { raise rebuild_error }) do
          error = assert_raises(Clickhouse::HeartbeatWriter::ServingRecoveryError) do
            Clickhouse::HeartbeatWriter.insert_rows([ attrs ])
          end

          assert_same maintenance_error, error.maintenance_error
          assert_same maintenance_error, error.cause
          assert_same rebuild_error, error.rebuild_error
          assert_match(/enqueue/i, error.message)
          assert_match(/synchronous rebuild/i, error.message)
          assert_match(/queue unavailable/, error.enqueue_error.message)
        end
      end
    end

    assert_equal 1, Clickhouse::Heartbeat.for_user(user).count
    assert_equal 0, Clickhouse::StatsReader.new(user).project_heartbeat_count("unrepaired")
    assert_equal [ "queue unavailable", "synchronous rebuild failed" ], reports.map { |error, _| error.message }
    assert reports.all? { |_, options| options[:handled] }
  end

  test "repeated rebuilds keep machine stats stable without multiplying correction history" do
    user = User.create!(timezone: "UTC")
    base = Time.zone.local(2026, 7, 10, 12)
    day = base.to_date

    create_heartbeat(user: user, time: base.to_f, project: "rebuilt", machine: "laptop", category: "coding", source_type: :test_entry)
    create_heartbeat(user: user, time: (base + 60.seconds).to_f, project: "rebuilt", machine: "laptop", category: "coding", source_type: :test_entry)
    initial_count = Clickhouse::HeartbeatIntervalDelta.where(user_id: user.id).count

    HeartbeatIntervals::UserRebuilder.call(user_id: user.id, reason: "first_rebuild")
    first_count = Clickhouse::HeartbeatIntervalDelta.where(user_id: user.id).count
    HeartbeatIntervals::UserRebuilder.call(user_id: user.id, reason: "second_rebuild")
    second_count = Clickhouse::HeartbeatIntervalDelta.where(user_id: user.id).count

    assert_equal 60, Clickhouse::StatsReader.new(user).total_seconds(
      start_time: day, end_time: day + 1.day, filters: { machine: "laptop" }
    )
    assert_equal first_count - initial_count, second_count - first_count
  end

  test "fractional intervals are summed before the final result is rounded" do
    user = User.create!(timezone: "UTC")
    base = Time.utc(2026, 7, 10, 12)
    day = base.to_date

    [ 0.0, 0.4, 0.8, 1.2 ].each do |offset|
      create_heartbeat(
        user: user, time: base.to_f + offset, project: "fractional",
        language: "Ruby", category: "coding", source_type: :test_entry
      )
    end

    raw = Clickhouse::Heartbeat.for_user(user).where(project: "fractional").duration_seconds
    reader = Clickhouse::StatsReader.new(user)
    assert_equal 1, raw
    assert_equal raw, reader.total_seconds(
      start_time: day, end_time: day + 1.day, filters: { project: "fractional" }
    )

    HeartbeatIntervals::UserRebuilder.call(user_id: user.id, reason: "fractional_rebuild")

    assert_equal raw, reader.total_seconds(
      start_time: day, end_time: day + 1.day, filters: { project: "fractional" }
    )
  end

  test "concurrent retries emit one serving fact" do
    user = User.create!(timezone: "UTC")
    attrs = {
      user_id: user.id,
      time: Time.utc(2026, 7, 10, 12).to_f,
      project: "concurrent",
      language: "Ruby",
      category: "coding",
      source_type: :test_entry
    }
    errors = Queue.new

    threads = 2.times.map do
      Thread.new do
        Clickhouse::HeartbeatWriter.insert_rows([ attrs ])
      rescue => e
        errors << e
      end
    end
    threads.each(&:join)

    flunk errors.pop.full_message unless errors.empty?
    assert_equal 1, Clickhouse::HeartbeatIntervalDelta.where(user_id: user.id).sum(:heartbeat_count_delta)
    assert_equal 1, Clickhouse::StatsReader.new(user).project_heartbeat_count("concurrent")
  end

  private

  def with_singleton_method(object, name, replacement)
    original = object.method(name)
    object.define_singleton_method(name, replacement)
    yield
  ensure
    object.define_singleton_method(name, original)
  end

  def insert_legacy_project_deltas(user_id, base, sequence)
    null_value = HeartbeatIntervals::NULL_DIMENSION_VALUE
    deltas = sequence.map.with_index do |(offset, _project), index|
      seconds = index.zero? ? 0 : 30
      {
        delta_id: Clickhouse::HeartbeatWriter.generate_id(base + index.seconds),
        user_id: user_id,
        day: base.to_date,
        time: (base + offset.seconds).to_f,
        project: "",
        language: "Ruby",
        editor: null_value,
        operating_system: null_value,
        machine: null_value,
        category: "coding",
        entity: "fixture_#{index}.rb",
        branch: null_value,
        user_seconds_delta: seconds,
        project_seconds_delta: seconds,
        language_seconds_delta: seconds,
        editor_seconds_delta: seconds,
        operating_system_seconds_delta: seconds,
        machine_seconds_delta: seconds,
        category_seconds_delta: seconds,
        entity_seconds_delta: 0,
        branch_seconds_delta: seconds,
        heartbeat_count_delta: 1,
        reason: "legacy_coalesced_project",
        created_at: base
      }
    end
    Clickhouse::HeartbeatIntervalDelta.insert_all(deltas)
  end
end
