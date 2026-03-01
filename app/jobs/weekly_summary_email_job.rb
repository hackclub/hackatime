class WeeklySummaryEmailJob < ApplicationJob
  queue_as :literally_whenever

  def perform(reference_time = Time.current)
    return unless Flipper.enabled?(:weekly_summary_emails)

    now_utc = reference_time.utc
    cutoff = 3.weeks.ago

    User.subscribed("weekly_summary")
        .where(created_at: cutoff..)
        .or(User.subscribed("weekly_summary").joins(:heartbeats).where(heartbeats: { time: cutoff.. }))
        .distinct
        .find_each do |user|
      WeeklySummaryUserEmailJob.perform_later(user.id, now_utc.iso8601)
    end
  end
end
