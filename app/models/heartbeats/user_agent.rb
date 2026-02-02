class Heartbeats::UserAgent < ApplicationRecord
  self.table_name = "heartbeat_user_agents"

  has_many :heartbeats, foreign_key: :user_agent_id, inverse_of: :heartbeat_user_agent

  validates :value, presence: true, uniqueness: true

  def self.resolve(value)
    return nil if value.blank?
    find_or_create_by(value: value)
  rescue ActiveRecord::RecordNotUnique
    find_by(value: value)
  end
end
