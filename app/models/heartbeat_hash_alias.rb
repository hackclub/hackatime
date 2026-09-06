class HeartbeatHashAlias < ApplicationRecord
  belongs_to :user

  validates :alias_hash, :canonical_hash, :heartbeat_id, presence: true
  validates :alias_hash, uniqueness: { scope: :user_id }
end
