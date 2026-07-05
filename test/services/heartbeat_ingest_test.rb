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

  test "direct heartbeat ingest persists normalized heartbeats and schedules dashboard rollup refresh" do
    user = User.create!(timezone: "UTC")

    assert_difference("user.heartbeats.count", 1) do
      assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ]) do
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
      end
    end

    heartbeat = user.heartbeats.order(:id).last
    assert_equal "vscode/1.0.0", heartbeat.user_agent
    assert_equal "coding", heartbeat.category
    assert_equal "laptop", heartbeat.machine
    assert_equal "203.0.113.10", heartbeat.ip_address.to_s
    assert_equal "t13d1516h2_8daaf6152771_02713d6af862", heartbeat.ja4.fingerprint
    assert_equal "direct_entry", heartbeat.source_type
  end

  test "direct heartbeat ingest reuses a JA4 record across requests" do
    user = User.create!(timezone: "UTC")
    ja4 = "t13d1516h2_8daaf6152771_02713d6af862"

    assert_difference({ "user.heartbeats.count" => 2, "Ja4.count" => 1 }) do
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

    assert_equal [ ja4 ], user.heartbeats.joins(:ja4).distinct.pluck("ja4s.fingerprint")
  end

  test "direct heartbeat ingest returns existing heartbeat for duplicate input" do
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

    clear_enqueued_jobs

    assert_no_difference("user.heartbeats.count") do
      result = HeartbeatIngest.call(
        user: user,
        mode: :direct,
        heartbeats: [ payload ],
        request_context: { ip_address: "203.0.113.20" }
      )

      assert_equal 1, result.total_count
      assert_equal 0, result.persisted_count
      assert_equal 1, result.duplicate_count
      assert_equal 0, result.failed_count
      assert_equal first_heartbeat.id, result.items.first.heartbeat.id
    end

    assert_no_enqueued_jobs only: DashboardRollupRefreshJob
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
    heartbeats = user.heartbeats.order(:time)
    assert_equal [ "Python", "Python" ], heartbeats.pluck(:language)
  end

  test "direct heartbeat ingest normalizes millisecond-scaled epoch times" do
    user = User.create!(timezone: "UTC")
    sane_time = Time.current.to_f

    HeartbeatIngest.call(
      user: user,
      mode: :direct,
      heartbeats: [ { entity: "src/main.rb", time: (sane_time * 1000).round, type: "file" } ]
    )

    assert_in_delta sane_time, user.heartbeats.sole.time, 1.0
  end

  test "import heartbeat ingest normalizes nanosecond-scaled epoch times" do
    user = User.create!(timezone: "UTC")
    sane_time = 1_700_000_000.0

    HeartbeatIngest.call(
      user: user,
      mode: :import,
      heartbeats: [ { entity: "/tmp/test.rb", type: "file", time: sane_time * 1_000_000_000 } ]
    )

    assert_in_delta sane_time, user.heartbeats.sole.time, 1.0
  end

  test "epoch normalization leaves sane and unrepairable values untouched" do
    ingest = HeartbeatIngest.new(user: User.new, mode: :direct, heartbeats: [])

    sane = Time.current.to_f
    assert_equal sane, ingest.send(:normalize_epoch_time, sane)
    # literal-year garbage is not scaled data; passes through (quarantined DB-side later)
    assert_equal 2026.0, ingest.send(:normalize_epoch_time, 2026)
    assert_equal(-9_999_999.0, ingest.send(:normalize_epoch_time, -9_999_999))
  end

  test "heartbeat_unique_by targets the composite index once time_epoch exists" do
    ingest = HeartbeatIngest.new(user: User.new, mode: :direct, heartbeats: [])

    assert_equal [ :fields_hash ], ingest.send(:heartbeat_unique_by)

    with_time_epoch_column = Heartbeat.column_names + [ "time_epoch" ]
    Heartbeat.define_singleton_method(:column_names) { with_time_epoch_column }
    begin
      assert_equal %i[fields_hash time_epoch], ingest.send(:heartbeat_unique_by)
    ensure
      Heartbeat.singleton_class.remove_method(:column_names)
    end
  end

  test "with_heartbeat_unique_by re-raises inside an open transaction after refreshing the schema cache" do
    ingest = HeartbeatIngest.new(user: User.new, mode: :direct, heartbeats: [])

    # transactional tests already wrap us in a transaction, so the guard applies
    calls = 0
    assert_raises(ArgumentError) do
      ingest.send(:with_heartbeat_unique_by) do |_unique_by|
        calls += 1
        raise ArgumentError, "No unique index found"
      end
    end
    assert_equal 1, calls
  end

  test "import heartbeat ingest deduplicates imported heartbeats and schedules dashboard rollup refresh" do
    user = User.create!(timezone: "UTC")

    assert_difference("user.heartbeats.count", 1) do
      assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ]) do
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
      end
    end

    heartbeat = user.heartbeats.order(:id).last
    assert_equal "wakapi_import", heartbeat.source_type
  end
end

# Outside a transaction (the production configuration for both ingest modes),
# the unique_by fallback must retry exactly once with a refreshed schema cache.
class HeartbeatIngestUniqueByFallbackTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "with_heartbeat_unique_by retries once after a schema-cache failure" do
    ingest = HeartbeatIngest.new(user: User.new, mode: :direct, heartbeats: [])

    calls = 0
    result = ingest.send(:with_heartbeat_unique_by) do |unique_by|
      calls += 1
      raise ActiveRecord::StatementInvalid, "no unique or exclusion constraint" if calls == 1
      unique_by
    end

    assert_equal 2, calls
    assert_equal [ :fields_hash ], result
  end

  test "with_heartbeat_unique_by does not retry more than once" do
    ingest = HeartbeatIngest.new(user: User.new, mode: :direct, heartbeats: [])

    calls = 0
    assert_raises(ActiveRecord::StatementInvalid) do
      ingest.send(:with_heartbeat_unique_by) do |_unique_by|
        calls += 1
        raise ActiveRecord::StatementInvalid, "no unique or exclusion constraint"
      end
    end
    assert_equal 2, calls
  end
end
