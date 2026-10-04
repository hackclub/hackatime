class WeeklySummaryEmailJob < ApplicationJob
  queue_as :literally_whenever

  def perform(reference_time = Time.current)
    return unless Flipper.enabled?(:weekly_summary_emails)

    now_utc = reference_time.utc
    cutoff = now_utc - 3.weeks

    eligible_users(cutoff).find_each do |user|
      WeeklySummaryUserEmailJob.perform_later(user.id, now_utc.iso8601)
    end
  end

  private

  def eligible_users(cutoff)
    active_user_ids = Heartbeat.where("time >= ?", cutoff.to_f).distinct.pluck(:user_id)
    subscribed = User.subscribed("weekly_summary")

    subscribed.where(created_at: cutoff..).or(subscribed.where(id: active_user_ids))
      .where.not(id: DeletionRequest.active.select(:user_id))
  end
end
