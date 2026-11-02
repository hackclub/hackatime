class CleanupExpiredSessionsJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    WebSession.where(updated_at: ...14.days.ago).in_batches.delete_all
  end
end
