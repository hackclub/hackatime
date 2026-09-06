class HeartbeatRemapRun < ApplicationRecord
  DEFAULT_BATCH_SIZE = 1_000

  has_many :remap_changes,
    class_name: "HeartbeatRemapChange",
    dependent: :delete_all,
    inverse_of: :heartbeat_remap_run
  has_many :remap_alias_changes,
    class_name: "HeartbeatRemapAliasChange",
    dependent: :delete_all,
    inverse_of: :heartbeat_remap_run

  enum :state, {
    queued: 0,
    running: 1,
    completed: 2,
    failed: 3,
    rolling_back: 4,
    rolled_back: 5
  }

  validates :batch_size, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 10_000 }
  validates :max_heartbeat_id, presence: true

  def terminal? = completed? || failed? || rolled_back?
end
