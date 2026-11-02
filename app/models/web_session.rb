class WebSession < ActiveRecord::SessionStore::Session
  self.table_name = "sessions"
  self.serializer = :null

  scope :for_user, ->(user) {
    where("data @> ? OR data @> ?", { user_id: user.id }.to_json, { impersonater_user_id: user.id }.to_json)
  }
end
