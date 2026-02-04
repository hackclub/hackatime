class Heartbeats::UserAgent < Heartbeats::LookupBase
  self.table_name = "heartbeat_user_agents"

  def self.lookup_column = :value

  has_many :heartbeats, foreign_key: :user_agent_id, inverse_of: :heartbeat_user_agent
end
