class LeaderboardUpdateJob < ApplicationJob
  queue_as :latency_10s

  include GoodJob::ActiveJobExtensions::Concurrency

  # Limits concurrency to 1 job per period/date combination
  good_job_control_concurrency_with(
    key: -> { "leaderboard_#{arguments[0] || 'daily'}_#{arguments[1] || Date.current.to_s}" },
    total: 1,
    drop: true
  )

  def perform(period = :daily, date = Date.current, force_update: false)
    Leaderboard.regenerate(period: period, date: date, force: force_update)
  end
end
