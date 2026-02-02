class Heartbeats::Project < ApplicationRecord
  self.table_name = "heartbeat_projects"

  belongs_to :user
  has_many :heartbeats, foreign_key: :project_id, inverse_of: :heartbeat_project

  validates :name, presence: true
  validates :user_id, uniqueness: { scope: :name }

  def self.resolve(user_id, name)
    return nil if name.blank? || user_id.blank?
    find_or_create_by(user_id: user_id, name: name)
  rescue ActiveRecord::RecordNotUnique
    find_by(user_id: user_id, name: name)
  end
end
