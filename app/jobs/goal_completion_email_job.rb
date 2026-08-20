class GoalCompletionEmailJob < ApplicationJob
  queue_as :latency_10s

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1, key: -> { "goal_completion_email_job_#{arguments.first}" }
  )

  def perform(notification_id)
    notification = GoalCompletionNotification.find(notification_id)
    return if notification.email_delivered_at.present?

    goal = notification.goal
    return unless goal.notify_by_email?

    user = goal.user
    return if user.pending_deletion?

    recipient_email = user.email_addresses.order(:id).pick(:email)
    return if recipient_email.blank?

    GoalCompletionMailer.reached(notification, recipient_email: recipient_email).deliver_now
    notification.update!(email_delivered_at: Time.current)
  end
end
