class Heartbeats::Machine < Heartbeats::UserScopedLookupBase
  self.table_name = "heartbeat_machines"

  has_many :heartbeats, foreign_key: :machine_id, inverse_of: :heartbeat_machine
end
