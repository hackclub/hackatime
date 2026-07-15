require "test_helper"

class HeartbeatIngestTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    Rails.cache.clear
    clear_enqueued_jobs
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
  end

  teardown do
    Rails.cache.clear
    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  def ch_count(user) = Clickhouse::Heartbeat.for_user(user).count

  test "direct heartbeat ingest persists normalized heartbeats to ClickHouse" do
    user = User.create!(timezone: "UTC")

    assert_enqueued_with(job: AttemptProjectRepoMappingJob, args: [ user.id, "hackatime" ]) do
      result = HeartbeatIngest.call(
        user: user,
        mode: :direct,
        heartbeats: [ {
          entity: "src/main.rb",
          plugin: "vscode/1.0.0",
          project: "hackatime",
          time: Time.current.to_f,
          type: "file"
        } ],
        request_context: {
          ip_address: "203.0.113.10",
          machine: "laptop",
          ja4: "t13d1516h2_8daaf6152771_02713d6af862"
        }
      )

      assert_equal 1, result.total_count
      assert_equal 1, result.persisted_count
      assert_equal 0, result.duplicate_count
      assert_equal 0, result.failed_count
      assert_equal 1, result.items.length
      assert_equal :accepted, result.items.first.status
    end

    assert_equal 1, ch_count(user)
    heartbeat = Clickhouse::Heartbeat.for_user(user).first
    assert_equal "vscode/1.0.0", heartbeat.user_agent
    assert_equal "coding", heartbeat.category
    assert_equal "laptop", heartbeat.machine
    assert_equal "203.0.113.10", heartbeat.ip_address
    assert_equal Ja4.find_by!(fingerprint: "t13d1516h2_8daaf6152771_02713d6af862").id, heartbeat.ja4_id
    assert_equal "direct_entry", heartbeat.source_type
    assert heartbeat.id.positive?
    assert heartbeat.fields_hash.present?
  end

  test "direct heartbeat ingest reuses a JA4 record across requests" do
    user = User.create!(timezone: "UTC")
    ja4 = "t13d1516h2_8daaf6152771_02713d6af862"

    assert_difference("Ja4.count", 1) do
      HeartbeatIngest.call(
        user: user,
        mode: :direct,
        heartbeats: [ { entity: "src/first.rb", time: Time.current.to_f, type: "file" } ],
        request_context: { ja4: ja4 }
      )
      HeartbeatIngest.call(
        user: user,
        mode: :direct,
        heartbeats: [ { entity: "src/second.rb", time: 1.second.from_now.to_f, type: "file" } ],
        request_context: { ja4: ja4 }
      )
    end

    assert_equal 2, ch_count(user)
    assert_equal [ Ja4.find_by!(fingerprint: ja4).id ],
      Clickhouse::Heartbeat.for_user(user).distinct.pluck(:ja4_id)
  end

  test "cross-request duplicate input collapses to one row under FINAL" do
    user = User.create!(timezone: "UTC")
    payload = {
      entity: "src/main.rb",
      plugin: "vscode/1.0.0",
      project: "hackatime",
      time: Time.current.to_f,
      type: "file"
    }

    first_result = HeartbeatIngest.call(
      user: user,
      mode: :direct,
      heartbeats: [ payload ],
      request_context: { ip_address: "203.0.113.10" }
    )
    first_heartbeat = first_result.items.first.heartbeat

    result = HeartbeatIngest.call(
      user: user,
      mode: :direct,
      heartbeats: [ payload ],
      request_context: { ip_address: "203.0.113.10" }
    )

    # Both requests insert; the identical (user_id, time, fields_hash) key
    # dedups in ClickHouse rather than at write time.
    assert_equal 1, result.persisted_count
    assert_equal first_heartbeat["fields_hash"], result.items.first.heartbeat["fields_hash"]
    assert_equal 1, ch_count(user)
  end

  test "retry after serving maintenance failure keeps canonical and serving counts deduplicated" do
    user = User.create!(timezone: "UTC")
    time = Time.utc(2026, 7, 10, 12)
    payload = {
      entity: "src/retry.rb",
      time: time.to_f,
      type: "file"
    }

    assert_enqueued_jobs 1, only: HeartbeatServingRebuildJob do
      with_singleton_method(HeartbeatIntervals::DeltaWriter, :emit_for_inserted_rows, ->(*) { raise "delta write failed" }) do
        assert_raises(RuntimeError) do
          HeartbeatIngest.call(user: user, mode: :direct, heartbeats: [ payload ])
        end
      end
    end
    perform_enqueued_jobs(only: HeartbeatServingRebuildJob)
    assert_equal 1, ch_count(user)
    assert_equal 1, Clickhouse::StatsReader.new(user).project_heartbeat_count(nil)

    HeartbeatIngest.call(user: user, mode: :direct, heartbeats: [ payload ])

    assert_equal 1, ch_count(user)
    assert_equal 1, Clickhouse::StatsReader.new(user).project_heartbeat_count(nil)
  end

  test "in-batch duplicate input is deduplicated and counted" do
    user = User.create!(timezone: "UTC")
    payload = {
      entity: "src/main.rb",
      plugin: "vscode/1.0.0",
      project: "hackatime",
      time: Time.current.to_f,
      type: "file"
    }

    result = HeartbeatIngest.call(user: user, mode: :direct, heartbeats: [ payload, payload.dup ])

    assert_equal 2, result.total_count
    assert_equal 1, result.persisted_count
    assert_equal 1, result.duplicate_count
    assert_equal 2, result.items.count { |item| item.status == :accepted }
    assert_equal 1, ch_count(user)
  end

  test "direct heartbeat ingest resolves last language within the batch" do
    user = User.create!(timezone: "UTC")
    now = Time.current.to_f

    result = HeartbeatIngest.call(
      user: user,
      mode: :direct,
      heartbeats: [
        {
          entity: "src/first.py",
          plugin: "vscode/1.0.0",
          project: "hackatime",
          time: now - 1,
          type: "file",
          language: "Python"
        },
        {
          entity: "src/second.rb",
          plugin: "vscode/1.0.0",
          project: "hackatime",
          time: now,
          type: "file",
          language: "<<LAST_LANGUAGE>>"
        }
      ]
    )

    assert_equal 2, result.persisted_count
    assert_equal [ "Python", "Python" ],
      Clickhouse::Heartbeat.for_user(user).order(:time).pluck(:language)
  end

  test "direct heartbeat ingest resolves last language from previously ingested heartbeats" do
    user = User.create!(timezone: "UTC")
    now = Time.current.to_f

    HeartbeatIngest.call(
      user: user,
      mode: :direct,
      heartbeats: [ { entity: "src/first.py", time: now - 10, type: "file", language: "Python" } ]
    )
    HeartbeatIngest.call(
      user: user,
      mode: :direct,
      heartbeats: [ { entity: "src/second.xyz", time: now, type: "file", language: "<<LAST_LANGUAGE>>" } ]
    )

    assert_equal [ "Python", "Python" ],
      Clickhouse::Heartbeat.for_user(user).order(:time).pluck(:language)
  end

  test "direct heartbeat ingest normalizes millisecond-scaled epoch times" do
    user = User.create!(timezone: "UTC")
    sane_time = Time.current.to_f

    HeartbeatIngest.call(
      user: user,
      mode: :direct,
      heartbeats: [ { entity: "src/main.rb", time: (sane_time * 1000).round, type: "file" } ]
    )

    assert_in_delta sane_time, Clickhouse::Heartbeat.for_user(user).sole.time, 1.0
  end

  test "import heartbeat ingest normalizes nanosecond-scaled epoch times" do
    user = User.create!(timezone: "UTC")
    sane_time = 1_700_000_000.0

    HeartbeatIngest.call(
      user: user,
      mode: :import,
      heartbeats: [ { entity: "/tmp/test.rb", type: "file", time: sane_time * 1_000_000_000 } ]
    )

    assert_in_delta sane_time, Clickhouse::Heartbeat.for_user(user).sole.time, 1.0
  end

  test "epoch normalization leaves sane and unrepairable values untouched" do
    ingest = HeartbeatIngest.new(user: User.new, mode: :direct, heartbeats: [])

    sane = Time.current.to_f
    assert_equal sane, ingest.send(:normalize_epoch_time, sane)
    # literal-year garbage is not scaled data; passes through (quarantined DB-side later)
    assert_equal 2026.0, ingest.send(:normalize_epoch_time, 2026)
    assert_equal(-9_999_999.0, ingest.send(:normalize_epoch_time, -9_999_999))
  end

  test "import heartbeat ingest deduplicates imported heartbeats" do
    user = User.create!(timezone: "UTC")

    result = HeartbeatIngest.call(
      user: user,
      mode: :import,
      heartbeats: [
        {
          entity: "/tmp/test.rb",
          type: "file",
          time: 1_700_000_000.0,
          project: "hackatime",
          language: "Ruby",
          is_write: true
        },
        {
          entity: "/tmp/test.rb",
          type: "file",
          time: 1_700_000_000.0,
          project: "hackatime",
          language: "Ruby",
          is_write: true
        }
      ]
    )

    assert_equal 2, result.total_count
    assert_equal 1, result.persisted_count
    assert_equal 1, result.duplicate_count
    assert_equal 0, result.failed_count

    assert_equal 1, ch_count(user)
    heartbeat = Clickhouse::Heartbeat.for_user(user).sole
    assert_equal "wakapi_import", heartbeat.source_type
  end

  test "re-importing the same dump does not duplicate rows" do
    user = User.create!(timezone: "UTC")
    heartbeats = [ { entity: "/tmp/test.rb", type: "file", time: 1_700_000_000.0, project: "hackatime", language: "Ruby", is_write: true } ]

    HeartbeatIngest.call(user: user, mode: :import, heartbeats: heartbeats)
    HeartbeatIngest.call(user: user, mode: :import, heartbeats: heartbeats)

    assert_equal 1, ch_count(user)
  end

  private

  def with_singleton_method(object, name, replacement)
    original = object.method(name)
    object.define_singleton_method(name, replacement)
    yield
  ensure
    object.define_singleton_method(name, original)
  end
end
