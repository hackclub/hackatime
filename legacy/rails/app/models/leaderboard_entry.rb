class LeaderboardEntry < ApplicationRecord
  belongs_to :leaderboard
  belongs_to :user

  validates :total_seconds, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :user_id, uniqueness: { scope: :leaderboard_id }
end
