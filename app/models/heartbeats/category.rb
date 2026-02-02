class Heartbeats::Category < ApplicationRecord
  self.table_name = "heartbeat_categories"

  has_many :heartbeats, foreign_key: :category_id, inverse_of: :heartbeat_category

  validates :name, presence: true, uniqueness: true

  def self.resolve(name)
    return nil if name.blank?
    find_or_create_by(name: name)
  rescue ActiveRecord::RecordNotUnique
    find_by(name: name)
  end
end
