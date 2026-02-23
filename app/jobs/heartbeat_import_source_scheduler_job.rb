class HeartbeatImportSourceSchedulerJob < ApplicationJob
  queue_as :latency_5m

  def perform
    HeartbeatImportSource.where(sync_enabled: true).where.not(status: :paused).pluck(:id).each do |source_id|
      HeartbeatImportSourceSyncJob.perform_later(source_id)
    end
  end
end
