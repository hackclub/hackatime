class Leaderboard < ApplicationRecord
  GLOBAL_TIMEZONE = "UTC"

  has_many :entries, class_name: "LeaderboardEntry", dependent: :destroy

  validates :start_date, presence: true

  enum :period_type, { daily: 0, last_7_days: 2 }

  REBUILDABLE_PERIODS = %i[daily last_7_days].freeze

  def self.current(period)
    date = LeaderboardDateRange.normalize_date(Date.current, period)
    board = where.not(finished_generating_at: nil)
              .find_by(start_date: date, period_type: period, timezone_utc_offset: nil, deleted_at: nil)
    LeaderboardUpdateJob.perform_later(period, date) unless board
    board
  end

  def finished_generating? = finished_generating_at.present?
  def period_end_date = start_date

  def date_range_text
    return "Last 24 hours" unless last_7_days?
    "#{(start_date - 6.days).strftime('%b %d')} - #{start_date.strftime('%b %d, %Y')}"
  end
end
