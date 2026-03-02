class HeartbeatExportCleanupJob < ApplicationJob
  queue_as :default

  def perform(blob_id)
    blob = ActiveStorage::Blob.find_by(id: blob_id)
    return if blob.nil?
    return unless blob.metadata["heartbeat_export"]

    blob.purge
  end
end
