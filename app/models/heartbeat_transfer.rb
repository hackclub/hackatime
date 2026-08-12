class HeartbeatTransfer < ApplicationRecord
  enum :status, { pending: 0, completed: 1, failed: 2 }

  validates :to_user_id, comparison: { other_than: :from_user_id }

  after_create_commit { HeartbeatTransferJob.perform_later(id) }
end
