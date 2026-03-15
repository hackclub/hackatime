require "test_helper"

class HeartbeatImportRemoteDownloadJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  setup do
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
  end

  teardown do
    ActiveJob::Base.queue_adapter = @original_queue_adapter
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "downloads the remote dump and enqueues the import job" do
    run = User.create!(timezone: "UTC").heartbeat_import_runs.create!(
      source_kind: :wakatime_download_link,
      state: :downloading_dump,
      remote_dump_status: "Manual download link received",
      message: "Downloading data dump..."
    )

    fake_client = Object.new
    fake_client.define_singleton_method(:download_dump) do |_url|
      '{"heartbeats":[]}'
    end

    with_dump_client(fake_client) do
      assert_enqueued_with(job: HeartbeatImportJob) do
        HeartbeatImportRemoteDownloadJob.perform_now(run.id, "https://wakatime.s3.amazonaws.com/export.json")
      end
    end
  end

  test "marks the run as failed when the direct download is rejected" do
    run = User.create!(timezone: "UTC").heartbeat_import_runs.create!(
      source_kind: :wakatime_download_link,
      state: :downloading_dump,
      message: "Downloading data dump..."
    )

    fake_client = Object.new
    fake_client.define_singleton_method(:download_dump) do |_url|
      raise HeartbeatImportDumpClient::RequestError, "Request failed with status 403"
    end

    with_dump_client(fake_client) do
      HeartbeatImportRemoteDownloadJob.perform_now(run.id, "https://wakatime.s3.amazonaws.com/export.json")
    end

    run.reload
    assert_equal "failed", run.state
    assert_equal "Import failed: Request failed with status 403", run.message
  end

  private

  def with_dump_client(fake_client)
    singleton_class = HeartbeatImportDumpClient.singleton_class
    singleton_class.alias_method :__original_new_for_test, :new
    singleton_class.define_method(:new) do |*|
      fake_client
    end
    yield
  ensure
    singleton_class.alias_method :new, :__original_new_for_test
    singleton_class.remove_method :__original_new_for_test
  end
end
