class GoalNotificationFanoutJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :literally_whenever

  def perform(reference_time = Time.current)
    now_utc = reference_time.utc

    step(:enqueue_user_notifications) do |step|
      eligible_users.find_each(start: step.cursor) do |user|
        GoalUserNotificationJob.perform_later(user.id, now_utc.iso8601)
        step.advance! from: user.id
      end
    end
  end

  private

  def eligible_users
    User.where(id: Goal.notifications_enabled.select(:user_id))
      .where.not(id: DeletionRequest.active.select(:user_id))
  end
end
