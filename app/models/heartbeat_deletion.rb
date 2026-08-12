class HeartbeatDeletion < ApplicationRecord
  enum :status, { pending: 0, completed: 1, failed: 2 }

  after_create_commit { HeartbeatDeletionJob.perform_later(id) }
end
