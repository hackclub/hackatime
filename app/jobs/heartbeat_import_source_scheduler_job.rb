class HeartbeatImportSourceSchedulerJob < ApplicationJob
  queue_as :latency_5m

  MAX_CONSECUTIVE_FAILURES = 10

  def perform
    return unless Flipper.enabled?(:wakatime_imports)

    HeartbeatImportSource
      .where(sync_enabled: true)
      .where.not(status: :paused)
      .where("consecutive_failures < ?", MAX_CONSECUTIVE_FAILURES)
      .find_each do |source|
        HeartbeatImportSourceSyncJob.perform_later(source.id)
      end
  end
end
