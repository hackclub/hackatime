class Heartbeats::Project < Heartbeats::UserScopedLookupBase
  self.table_name = "heartbeat_projects"

  has_many :heartbeats, foreign_key: :project_id, inverse_of: :heartbeat_project
end
