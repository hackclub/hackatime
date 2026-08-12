class HeartbeatJa4Nullification < ApplicationRecord
  after_create_commit { HeartbeatJa4NullificationJob.perform_later(id) }
end
