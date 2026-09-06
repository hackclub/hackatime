class HeartbeatRemapChange < ApplicationRecord
  belongs_to :heartbeat_remap_run, inverse_of: :remap_changes

  enum :action, {
    update: "update",
    duplicate_soft_delete: "duplicate_soft_delete",
    unsafe_collision: "unsafe_collision",
    stale: "stale"
  }, prefix: true

  validates :heartbeat_id, presence: true
end
