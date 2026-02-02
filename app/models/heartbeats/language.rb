class Heartbeats::Language < Heartbeats::LookupBase
  self.table_name = "heartbeat_languages"

  has_many :heartbeats, foreign_key: :language_id, inverse_of: :heartbeat_language
end
