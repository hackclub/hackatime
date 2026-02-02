class Heartbeats::Editor < ApplicationRecord
  self.table_name = "heartbeat_editors"

  has_many :heartbeats, foreign_key: :editor_id, inverse_of: :heartbeat_editor

  validates :name, presence: true, uniqueness: true

  def self.resolve(name)
    return nil if name.blank?
    find_or_create_by(name: name)
  rescue ActiveRecord::RecordNotUnique
    find_by(name: name)
  end
end
