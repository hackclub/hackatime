class HeartbeatRemapAliasChange < ApplicationRecord
  belongs_to :heartbeat_remap_run, inverse_of: :remap_alias_changes
  belongs_to :user

  validates :heartbeat_id, :alias_hash, :after_heartbeat_id, :after_canonical_hash, presence: true
  validates :alias_hash, uniqueness: { scope: %i[heartbeat_remap_run_id user_id] }
end
