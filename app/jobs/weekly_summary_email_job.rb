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
    # Query ClickHouse for user_ids with recent activity (can't do cross-DB subquery)
    active_user_ids = Heartbeat.where("time >= ?", cutoff.to_f)
                               .distinct
                               .pluck(:user_id)

    User.subscribed("weekly_summary").where(
      User.arel_table[:created_at].gteq(cutoff).or(User.arel_table[:id].in(active_user_ids))
    ).where.not(id: DeletionRequest.active.select(:user_id))
  end
end
