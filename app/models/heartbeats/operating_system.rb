class Heartbeats::OperatingSystem < Heartbeats::LookupBase
  self.table_name = "heartbeat_operating_systems"

  has_many :heartbeats, foreign_key: :operating_system_id, inverse_of: :heartbeat_operating_system
end
