class RecordAdminApiKeyUsageJob < ApplicationJob
  queue_as :latency_10s

  # Keep the enqueue and the sampling-window claim in the same database transaction.
  self.enqueue_after_transaction_commit = false

  def perform(key_id, used_at)
    AdminApiKey.where(id: key_id)
      .where("last_used_at IS NULL OR last_used_at < ?", used_at)
      .update_all(last_used_at: used_at)
  end
end
