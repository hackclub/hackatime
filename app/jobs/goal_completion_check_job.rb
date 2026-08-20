class GoalCompletionCheckJob < ApplicationJob
  queue_as :latency_10s

  include GoodJob::ActiveJobExtensions::Concurrency

  def self.schedule_for(user_id)
    goals = Goal.where(user_id: user_id)
    return unless goals.where(notify_by_email: true).or(goals.where(notify_by_slack: true)).exists?

    perform_later(user_id)
  end

  good_job_control_concurrency_with(
    total_limit: 1, key: -> { "goal_completion_check_job_#{arguments.first}" }
  )

  def perform(user_id)
    user = User.find_by(id: user_id)
    return if user.nil? || user.pending_deletion?

    goals = user.goals.where(notify_by_email: true).or(user.goals.where(notify_by_slack: true))
    return if goals.empty?

    ProgrammingGoalsProgressService.new(user: user, goals: goals).call.each do |progress|
      next unless progress[:complete]

      notification = GoalCompletionNotification.create_or_find_by!(
        goal_id: progress[:id],
        period: progress[:period],
        period_started_at: Time.zone.parse(progress[:period_start])
      ) do |record|
        record.target_seconds = progress[:target_seconds]
        record.tracked_seconds = progress[:tracked_seconds]
        record.languages = progress[:languages]
        record.projects = progress[:projects]
      end

      goal = notification.goal
      GoalCompletionEmailJob.perform_later(notification.id) if goal.notify_by_email? && notification.email_delivered_at.nil?
      GoalCompletionSlackJob.perform_later(notification.id) if goal.notify_by_slack? && notification.slack_delivered_at.nil?
    end
  end
end
