class Leaderboard < ApplicationRecord
  GLOBAL_TIMEZONE = "UTC"

  has_many :entries,
    class_name: "LeaderboardEntry",
    dependent: :destroy

  validates :start_date, presence: true

  enum :period_type, {
    daily: 0,
    weekly: 1,
    last_7_days: 2,
    daily_timezone_normalized: 3,
    daily_regional: 4,
    daily_timezone_specific: 5
  }

  def finished_generating?
    finished_generating_at.present?
  end

  def period_end_date
    case period_type
    when "weekly"
      start_date + 6.days
    when "last_7_days"
      start_date
    else
      start_date
    end
  end

  def date_range_text
    if weekly?
      "#{start_date.strftime('%b %d')} - #{period_end_date.strftime('%b %d, %Y')}"
    else
      start_date.strftime("%B %d, %Y")
    end
  end
end
