class Heartbeats::LookupBase < ApplicationRecord
  self.abstract_class = true

  def self.lookup_column = :name

  validates lookup_column, presence: true, uniqueness: true

  def self.resolve(value)
    return nil if value.blank?
    create_or_find_by(lookup_column => value)
  end
end
