require "test_helper"

class Clickhouse::HeartbeatIntervalDeltaTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

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
    assert_equal 80, Clickhouse::HeartbeatProjectSummary.seconds_for(user_id: 123, project: "hackatime")
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
    assert_equal 60, Clickhouse::HeartbeatProjectSummary.seconds_for(user_id: user.id, project: "serving")
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

  test "bulk soft delete rebuilds serving totals with correction deltas" do
    user = User.create!(timezone: "UTC")
    base = Time.zone.local(2026, 7, 10, 12)

    create_heartbeat(user: user, time: base.to_f, project: "deleted", language: "Ruby", category: "coding", source_type: :test_entry)
    create_heartbeat(user: user, time: (base + 60.seconds).to_f, project: "deleted", language: "Ruby", category: "coding", source_type: :test_entry)
    day = base.to_date

    assert_equal 60, Clickhouse::HeartbeatUserDailyStat.seconds_for(user_id: user.id, start_date: day, end_date: day)

    Clickhouse::HeartbeatWriter.soft_delete_user_heartbeats!(user.id)

    assert_equal 0, Clickhouse::HeartbeatUserDailyStat.seconds_for(user_id: user.id, start_date: day, end_date: day)
    assert_equal 0, Clickhouse::HeartbeatProjectSummary.seconds_for(user_id: user.id, project: "deleted")
  end

  test "import rebuild corrects out of order interval deltas" do
    user = User.create!(timezone: "UTC")
    base = Time.zone.local(2026, 7, 10, 12)
    day = base.to_date

    create_heartbeat(user: user, time: base.to_f, project: "imported", language: "Ruby", category: "coding", source_type: :test_entry)
    create_heartbeat(user: user, time: (base + 120.seconds).to_f, project: "imported", language: "Ruby", category: "coding", source_type: :test_entry)

    assert_equal 120, Clickhouse::HeartbeatUserDailyStat.seconds_for(user_id: user.id, start_date: day, end_date: day)

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

    assert_equal 120, Clickhouse::HeartbeatUserDailyStat.seconds_for(user_id: user.id, start_date: day, end_date: day)
    assert_equal 120, Clickhouse::HeartbeatProjectSummary.seconds_for(user_id: user.id, project: "imported")
  end

  test "direct late heartbeat rebuilds the affected user intervals" do
    user = User.create!(timezone: "UTC")
    base = Time.zone.local(2026, 7, 10, 12)
    day = base.to_date

    create_heartbeat(user: user, time: base.to_f, project: "late", language: "Ruby", category: "coding", source_type: :test_entry)
    create_heartbeat(user: user, time: (base + 120.seconds).to_f, project: "late", language: "Ruby", category: "coding", source_type: :test_entry)
    create_heartbeat(user: user, time: (base + 60.seconds).to_f, project: "late", language: "Python", category: "coding", source_type: :test_entry)

    assert_equal 120, Clickhouse::HeartbeatUserDailyStat.seconds_for(user_id: user.id, start_date: day, end_date: day)
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
    assert_equal 60, Clickhouse::HeartbeatUserDailyStat.seconds_for(user_id: user.id, start_date: day, end_date: day)
  end

  test "enqueues recovery when canonical insert succeeds before delta maintenance fails" do
    user = User.create!(timezone: "UTC")
    attrs = {
      user_id: user.id,
      time: Time.utc(2026, 7, 10, 12).to_f,
      project: "recovery",
      language: "Ruby",
      category: "coding",
      source_type: :test_entry
    }

    assert_enqueued_with(
      job: HeartbeatServingRebuildJob,
      args: [ [ user.id ], { reason: "heartbeat_write_recovery" } ]
    ) do
      original_writer = HeartbeatIntervals::DeltaWriter.method(:emit_for_inserted_rows)
      HeartbeatIntervals::DeltaWriter.define_singleton_method(:emit_for_inserted_rows) { |*| raise "delta write failed" }
      begin
        error = assert_raises(RuntimeError) do
          Clickhouse::HeartbeatWriter.insert_rows([ attrs ])
        end
        assert_equal "delta write failed", error.message
      ensure
        HeartbeatIntervals::DeltaWriter.define_singleton_method(:emit_for_inserted_rows, original_writer)
      end
    end

    assert_equal 1, Clickhouse::Heartbeat.for_user(user).count
    assert_equal 0, Clickhouse::HeartbeatProjectSummary.heartbeat_count_for(user_id: user.id, project: "recovery")
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

  test "rebuild emits one net correction generation instead of retracting first" do
    user = User.create!(timezone: "UTC")
    base = Time.utc(2026, 7, 10, 12)

    create_heartbeat(
      user: user, time: base.to_f, project: "net", language: "Ruby",
      category: "coding", source_type: :test_entry
    )
    create_heartbeat(
      user: user, time: (base + 120.seconds).to_f, project: "net", language: "Ruby",
      category: "coding", source_type: :test_entry
    )
    Clickhouse::HeartbeatWriter.insert_rows(
      [
        {
          user_id: user.id, time: (base + 60.seconds).to_f, project: "net",
          language: "Python", category: "coding", source_type: :test_entry
        }
      ],
      maintain_serving_tables: false
    )

    HeartbeatIntervals::UserRebuilder.call(user_id: user.id, reason: "net_rebuild")

    reasons = Clickhouse::HeartbeatIntervalDelta.where(user_id: user.id).distinct.pluck(:reason)
    assert_includes reasons, "net_rebuild"
    assert_not reasons.any? { |reason| reason.end_with?("_retract") }
    assert_equal Clickhouse::Heartbeat.attributed_durations_by(Clickhouse::Heartbeat.for_user(user), :language),
      Clickhouse::StatsReader.new(user).dimension_durations(dimension: :language)
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
    assert_equal 1, Clickhouse::HeartbeatProjectSummary.heartbeat_count_for(user_id: user.id, project: "concurrent")
  end
end
