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
              machine: "laptop"
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
    assert_equal "direct_entry", heartbeat.source_type
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
