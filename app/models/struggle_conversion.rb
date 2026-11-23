class StruggleConversion < ApplicationRecord
  belongs_to :user
  has_many :struggle_windows, dependent: :nullify

  validates :windows_count, numericality: { only_integer: true, greater_than: 0 }
  validates :total_sp_converted, numericality: { greater_than_or_equal_to: 0 }
  validates :total_raw_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :total_credited_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :converted_at, presence: true
end
