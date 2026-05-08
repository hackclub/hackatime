class Leaderboard < ApplicationRecord
  CACHE_EXPIRATION = 10.minutes

  has_many :entries,
    class_name: "LeaderboardEntry",
    dependent: :destroy

  validates :start_date, presence: true

  enum :period_type, {
    daily: 0,
    last_7_days: 2
  }

  scope :ready, -> {
    where.not(finished_generating_at: nil).where(deleted_at: nil, timezone_utc_offset: nil)
  }

  def self.fetch(period: :daily, date: Date.current)
    period = period.to_sym
    date = normalize_date(date, period)
    key = cache_key(period, date)

    if (cached = Rails.cache.read(key))
      return cached
    end

    board = ready.find_by(start_date: date, period_type: period)
    if board
      write_cache(board, period: period, date: date)
      return board
    end

    LeaderboardUpdateJob.perform_later(period, date)
    nil
  end

  def self.regenerate(period:, date:, force: false)
    Builder.new(period: period, date: date).call(force: force)
  end

  def self.normalize_date(date, _period)
    date = Date.current if date.blank?
    date.is_a?(Date) ? date : Date.parse(date.to_s)
  end

  def self.write_cache(board, period:, date:)
    Rails.cache.write(cache_key(period, date), board, expires_in: CACHE_EXPIRATION)
  end

  def finished_generating?
    finished_generating_at.present?
  end

  def period_end_date
    start_date
  end

  def range
    case period_type.to_sym
    when :last_7_days
      ((start_date - 6.days).beginning_of_day...start_date.end_of_day)
    else
      24.hours.ago...Time.current
    end
  end

  def date_range_text
    if last_7_days?
      "#{(start_date - 6.days).strftime('%b %d')} - #{start_date.strftime('%b %d, %Y')}"
    else
      "Last 24 hours"
    end
  end

  def self.cache_key(period, date)
    "leaderboard_#{period}_#{date}"
  end
  private_class_method :cache_key
end
