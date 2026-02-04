class Heartbeats::Editor < Heartbeats::LookupBase
  self.table_name = "heartbeat_editors"

  has_many :heartbeats, foreign_key: :editor_id, inverse_of: :heartbeat_editor
end
