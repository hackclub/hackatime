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

  test "direct heartbeat ingest records event participation for inserted heartbeats" do
    user = User.create!(timezone: "UTC")
    high_seas_time = Time.zone.parse("2024-12-15 12:00:00").to_f

    HeartbeatIngest.call(
      user: user,
      mode: :direct,
      heartbeats: [ { entity: "src/event.rb", time: high_seas_time, type: "file" } ]
    )

    assert user.reload.event_participation.set?(:high_seas)
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

  test "import heartbeat ingest records event participation only for inserted heartbeats" do
    user = User.create!(timezone: "UTC")
    high_seas_time = Time.zone.parse("2024-12-15 12:00:00").to_f

    HeartbeatIngest.call(
      user: user,
      mode: :import,
      heartbeats: [ {
        entity: "/tmp/event.rb",
        type: "file",
        time: high_seas_time,
        project: "hackatime",
        language: "Ruby"
      } ]
    )

    assert user.reload.event_participation.set?(:high_seas)
  end
end
