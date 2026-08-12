class HeartbeatCutover < ApplicationRecord
  validates :source_through_id, :backfilled_through_id,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
