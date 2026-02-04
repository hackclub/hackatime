class Heartbeats::UserScopedLookupBase < ApplicationRecord
  self.abstract_class = true

  belongs_to :user

  validates :name, presence: true

  def self.resolve(user_id, name)
    return nil if user_id.blank? || name.blank?
    create_or_find_by(user_id: user_id, name: name)
  end
end
