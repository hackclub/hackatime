class Leaderboard < ApplicationRecord
  GLOBAL_TIMEZONE = "UTC"

  has_many :entries,
    class_name: "LeaderboardEntry",
    dependent: :destroy

  validates :start_date, presence: true

  enum :period_type, {
    daily: 0,
    last_7_days: 2
  }

  def finished_generating?
    finished_generating_at.present?
  end

  def period_end_date
    start_date
  end

  def date_range_text
    if last_7_days?
      "#{(start_date - 6.days).strftime('%b %d')} - #{start_date.strftime('%b %d, %Y')}"
    else
      start_date.strftime("%B %d, %Y")
    end
  end
end
