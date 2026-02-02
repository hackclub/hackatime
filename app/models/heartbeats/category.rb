class Heartbeats::Category < Heartbeats::LookupBase
  self.table_name = "heartbeat_categories"

  has_many :heartbeats, foreign_key: :category_id, inverse_of: :heartbeat_category
end
