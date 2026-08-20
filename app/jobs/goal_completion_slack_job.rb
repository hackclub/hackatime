class GoalCompletionSlackJob < ApplicationJob
  queue_as :latency_10s

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1, key: -> { "goal_completion_slack_job_#{arguments.first}" }
  )

  def perform(notification_id)
    notification = GoalCompletionNotification.find(notification_id)
    return if notification.slack_delivered_at.present?

    goal = notification.goal
    return unless goal.notify_by_slack?

    user = goal.user
    return if user.pending_deletion? || user.slack_uid.blank?

    duration = ApplicationController.helpers.short_time_simple(notification.target_seconds)
    scope = notification_scope(notification)
    message = ":tada: You reached your #{notification.period} coding goal of *#{duration}*#{scope}!"
    response = HTTP.auth("Bearer #{ENV['SAILORS_LOG_SLACK_BOT_OAUTH_TOKEN']}")
      .post("https://slack.com/api/chat.postMessage", json: { channel: user.slack_uid, text: message })
    data = JSON.parse(response.body)
    raise "Failed to send goal completion Slack notification: #{data["error"]}" unless data["ok"]

    notification.update!(slack_delivered_at: Time.current)
  end

  private

  def notification_scope(notification)
    filters = []
    filters << "#{notification.languages.to_sentence} coding" if notification.languages.any?
    filters << notification.projects.to_sentence if notification.projects.any?
    filters.any? ? " for #{filters.join(" in ")}" : ""
  end
end
