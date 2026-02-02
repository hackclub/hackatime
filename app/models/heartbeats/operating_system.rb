class Heartbeats::OperatingSystem < ApplicationRecord
  self.table_name = "heartbeat_operating_systems"

  has_many :heartbeats, foreign_key: :operating_system_id, inverse_of: :heartbeat_operating_system

  validates :name, presence: true, uniqueness: true

  def self.resolve(name)
    return nil if name.blank?
    find_or_create_by(name: name)
  rescue ActiveRecord::RecordNotUnique
    find_by(name: name)
  end
end
