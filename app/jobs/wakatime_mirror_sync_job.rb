class WakatimeMirrorSyncJob < ApplicationJob
  queue_as :default

  def perform(mirror)
    mirror.sync_heartbeats
  end
end
