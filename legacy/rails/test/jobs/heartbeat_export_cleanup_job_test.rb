require "test_helper"

class HeartbeatExportCleanupJobTest < ActiveJob::TestCase
  test "purges heartbeat export blob" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("{\"sample\":true}"),
      filename: "heartbeats_test.json",
      content_type: "application/json",
      metadata: { "heartbeat_export" => true }
    )

    assert_difference -> { ActiveStorage::Blob.count }, -1 do
      HeartbeatExportCleanupJob.perform_now(blob.id)
    end
  end

  test "does not purge blob without heartbeat export metadata" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("test"),
      filename: "notes.txt",
      content_type: "text/plain"
    )

    assert_no_difference -> { ActiveStorage::Blob.count } do
      HeartbeatExportCleanupJob.perform_now(blob.id)
    end

    blob.purge
  end
end
