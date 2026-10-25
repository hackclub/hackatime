class LeaderboardEntry < ApplicationRecord
  belongs_to :leaderboard
  belongs_to :user

  scope :participating, -> { joins(:user).merge(User.leaderboard_participants) }

  validates :total_seconds, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :user_id, uniqueness: { scope: :leaderboard_id }

  def lost_unprompted_ai_time? = unprompted_ai_seconds >= 15.minutes
end
