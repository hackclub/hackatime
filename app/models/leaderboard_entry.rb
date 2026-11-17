class LeaderboardEntry < ApplicationRecord
  # AI coding earns 90% for the first three hours of a day. After that the
  # rate decays exponentially, halving roughly every 1.4 hours, so a day of
  # AI coding can never be worth more than 90% * (3h + 2h) = 4.5 hours.
  AI_CREDIT_RATE = 0.9
  AI_FULL_RATE_SECONDS = 3.hours.to_i
  AI_DECAY_SECONDS = 2.hours.to_i

  def self.credited_ai_seconds(seconds)
    return AI_CREDIT_RATE * seconds if seconds <= AI_FULL_RATE_SECONDS

    decayed = AI_DECAY_SECONDS * (1 - Math.exp(-(seconds - AI_FULL_RATE_SECONDS).to_f / AI_DECAY_SECONDS))
    AI_CREDIT_RATE * (AI_FULL_RATE_SECONDS + decayed)
  end

  belongs_to :leaderboard
  belongs_to :user

  scope :participating, -> { joins(:user).merge(User.leaderboard_participants) }

  validates :total_seconds, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :user_id, uniqueness: { scope: :leaderboard_id }

  def lost_ai_time? = discounted_ai_seconds >= 15.minutes
end
