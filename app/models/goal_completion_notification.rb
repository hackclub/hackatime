class GoalCompletionNotification < ApplicationRecord
  belongs_to :goal

  validates :period, inclusion: { in: Goal::PERIODS }
  validates :period_started_at, presence: true
  validates :target_seconds, :tracked_seconds,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
