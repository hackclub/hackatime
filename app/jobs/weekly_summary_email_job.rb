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
    users = User.arel_table
    heartbeats = Heartbeat.arel_table

    recent_activity_exists = Heartbeat.unscoped
      .where(heartbeats[:user_id].eq(users[:id]))
      .where(heartbeats[:deleted_at].eq(nil))
      .where(heartbeats[:time].gteq(cutoff.to_f))
      .arel
      .exists

    User.subscribed("weekly_summary").where(
      users[:created_at].gteq(cutoff).or(recent_activity_exists)
    )
  end
end
