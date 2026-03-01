require "test_helper"
require "webmock/minitest"

class HeartbeatImportSourceSyncJobTest < ActiveJob::TestCase
  setup do
    Flipper.enable(:wakatime_imports_mirrors)
  end

  teardown do
    Flipper.disable(:wakatime_imports_mirrors)
  end

  def create_source(user:, **attrs)
    user.create_heartbeat_import_source!(
      {
        provider: :wakatime_compatible,
        endpoint_url: "https://wakatime.com/api/v1",
        encrypted_api_key: "import-key",
        sync_enabled: true,
        status: :idle
      }.merge(attrs)
    )
  end

  def queued_jobs_for(job_class)
    GoodJob::Job.where(job_class: job_class)
  end

  test "full-history default schedules backfill windows and re-enqueues coordinator" do
    GoodJob::Job.delete_all
    user = User.create!(timezone: "UTC")
    source = create_source(user: user)

    stub_request(:get, "https://wakatime.com/api/v1/users/current/all_time_since_today")
      .to_return(
        status: 200,
        body: {
          data: {
            range: {
              start_date: (Date.current - 10.days).iso8601
            }
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    HeartbeatImportSourceSyncJob.perform_now(source.id)

    day_jobs = queued_jobs_for("HeartbeatImportSourceSyncDayJob")
    sync_jobs = queued_jobs_for("HeartbeatImportSourceSyncJob")

    assert_equal 5, day_jobs.count
    assert_equal 1, sync_jobs.count

    source.reload
    assert source.backfilling?
    assert_equal(Date.current - 5.days, source.backfill_cursor_date)
  end

  test "range override limits scheduled days" do
    GoodJob::Job.delete_all
    user = User.create!(timezone: "UTC")
    start_date = Date.current - 2.days
    end_date = Date.current - 1.day
    source = create_source(
      user: user,
      initial_backfill_start_date: start_date,
      initial_backfill_end_date: end_date
    )

    HeartbeatImportSourceSyncJob.perform_now(source.id)

    day_jobs = queued_jobs_for("HeartbeatImportSourceSyncDayJob")
    day_args = day_jobs.map { |job| job.serialized_params.fetch("arguments").last }

    assert_equal 2, day_jobs.count
    assert_includes day_args, start_date.iso8601
    assert_includes day_args, end_date.iso8601
  end

  test "ongoing sync enqueues today and yesterday" do
    GoodJob::Job.delete_all
    user = User.create!(timezone: "UTC")
    source = create_source(
      user: user,
      status: :syncing,
      initial_backfill_start_date: Date.current - 7.days,
      initial_backfill_end_date: Date.current,
      backfill_cursor_date: nil,
      last_synced_at: Time.current
    )

    HeartbeatImportSourceSyncJob.perform_now(source.id)

    day_jobs = queued_jobs_for("HeartbeatImportSourceSyncDayJob")
    scheduled_dates = day_jobs.map { |job| Date.iso8601(job.serialized_params.fetch("arguments").last) }

    assert_equal 2, day_jobs.count
    assert_includes scheduled_dates, Date.current
    assert_includes scheduled_dates, Date.yesterday
  end

  test "day job imports and dedupes by fields_hash" do
    user = User.create!(timezone: "UTC")
    source = create_source(user: user, status: :syncing)
    timestamp = Time.current.to_f

    payload = [
      {
        entity: "src/a.rb",
        type: "file",
        category: "coding",
        project: "alpha",
        language: "Ruby",
        editor: "VS Code",
        time: timestamp
      },
      {
        entity: "src/a.rb",
        type: "file",
        category: "coding",
        project: "alpha",
        language: "Ruby",
        editor: "VS Code",
        time: timestamp
      }
    ]

    stub_request(:get, "https://wakatime.com/api/v1/users/current/heartbeats")
      .with(query: { "date" => Date.current.iso8601 })
      .to_return(
        status: 200,
        body: { data: payload }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    HeartbeatImportSourceSyncDayJob.perform_now(source.id, Date.current.iso8601)

    assert_equal 1, user.heartbeats.where(source_type: :wakapi_import).count
    assert source.reload.last_synced_at.present?
  end

  test "day job pauses source on auth errors" do
    user = User.create!(timezone: "UTC")
    source = create_source(user: user, status: :syncing)

    stub_request(:get, "https://wakatime.com/api/v1/users/current/heartbeats")
      .with(query: { "date" => Date.current.iso8601 })
      .to_return(status: 401, body: "{}")

    HeartbeatImportSourceSyncDayJob.perform_now(source.id, Date.current.iso8601)

    source.reload
    assert source.paused?
    assert_not source.sync_enabled
    assert_includes source.last_error_message, "Authentication failed"
  end

  test "day job marks transient errors for retry" do
    user = User.create!(timezone: "UTC")
    source = create_source(user: user, status: :syncing)

    stub_request(:get, "https://wakatime.com/api/v1/users/current/heartbeats")
      .with(query: { "date" => Date.current.iso8601 })
      .to_return(status: 500, body: "{}")

    assert_raises(WakatimeCompatibleClient::TransientError) do
      HeartbeatImportSourceSyncDayJob.new.perform(source.id, Date.current.iso8601)
    end

    source.reload
    assert source.failed?
    assert_equal 1, source.consecutive_failures
  end

  test "coordinator does nothing when imports and mirrors are disabled" do
    GoodJob::Job.delete_all
    user = User.create!(timezone: "UTC")
    source = create_source(user: user)
    Flipper.disable(:wakatime_imports_mirrors)

    HeartbeatImportSourceSyncJob.perform_now(source.id)

    assert_equal 0, queued_jobs_for("HeartbeatImportSourceSyncDayJob").count
    assert_equal "idle", source.reload.status
  end
end
