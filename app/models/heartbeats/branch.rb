class Heartbeats::Branch < Heartbeats::UserScopedLookupBase
  self.table_name = "heartbeat_branches"

  has_many :heartbeats, foreign_key: :branch_id, inverse_of: :heartbeat_branch
end
