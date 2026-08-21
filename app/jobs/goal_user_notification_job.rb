class GoalUserNotificationJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :literally_whenever

  include ErrorReporting

  Notification = Struct.new(:tracked_seconds, :remaining_seconds, keyword_init: true)

  def perform(user_id, now_utc_iso8601)
    user = User.find_by(id: user_id)
    return if user.nil? || user.pending_deletion?

    now_utc = Time.zone.parse(now_utc_iso8601)
    timezone = ActiveSupport::TimeZone[user.timezone] || ActiveSupport::TimeZone["UTC"]

    Time.use_zone(timezone) do
      now = Time.zone.now
      goals = user.goals.notifications_enabled.order(:created_at)
      return if goals.empty?

      # Cursor holds the last handled goal id so an interrupted run resumes
      # at the next goal without redoing earlier progress lookups.
      step(:notify_goals) do |step|
        progress_by_goal_id = ProgrammingGoalsProgressService
          .new(user: user, goals: goals).call
          .index_by { |progress| progress[:id] }

        goals.each do |goal|
          next if step.cursor && goal.id <= step.cursor

          notify_goal(user, goal, progress_by_goal_id[goal.id.to_s], now)
          step.set!(goal.id)
        end
      end
    end
  end

  private

  def notify_goal(user, goal, progress, now)
    return unless progress

    window = goal.time_window(now: now)
    return if goal.last_missed_notification_period_start == window.begin
    return unless goal.about_to_miss?(now: now, tracked_seconds: progress[:tracked_seconds])

    notification = Notification.new(
      tracked_seconds: progress[:tracked_seconds],
      remaining_seconds: (window.end - now).to_i
    )

    return unless deliver_notifications(user, goal, notification)

    goal.update!(last_missed_notification_period_start: window.begin)
  end

  # Sends over every enabled channel and reports whether any delivery
  # succeeded. The caller only records the notification when this returns
  # true, so failed channels are retried on the next scheduled run.
  def deliver_notifications(user, goal, notification)
    results = []
    results << safely("Slack") { deliver_slack(user, goal, notification) } if goal.notify_slack? && user.slack_uid.present?
    results << safely("email") { deliver_email(user, goal, notification) } if goal.notify_email? && user.subscribed?("goal_notifications")

    return false if results.empty?

    delivered = results.any?
    unless delivered
      report_message("All goal notification channels failed for user #{user.id}, goal #{goal.id}", level: :warn)
    end
    delivered
  end

  # A failed delivery must never abort the run and skip other goals or
  # channels; report it and let the next scheduled run retry this goal.
  def safely(channel)
    yield
  rescue StandardError => e
    report_error(e, message: "Goal notification #{channel} delivery failed")
    false
  end

  def slack_message(goal, notification)
    ":alarm_clock: Heads up! You've coded for " \
      "*#{ApplicationController.helpers.short_time_simple(notification.tracked_seconds)}* of your " \
      "*#{ApplicationController.helpers.short_time_simple(goal.target_seconds)}* #{goal.period_adjective} goal, " \
      "with *#{ApplicationController.helpers.short_time_simple(notification.remaining_seconds)}* left. You've got this!"
  end

  def deliver_slack(user, goal, notification)
    token = ENV["SAILORS_LOG_SLACK_BOT_OAUTH_TOKEN"]
    return false if token.blank?

    response = HTTP.auth("Bearer #{token}")
      .post("https://slack.com/api/chat.postMessage",
            json: { channel: user.slack_uid, text: slack_message(goal, notification) })

    data = JSON.parse(response.body.to_s)
    return true if data["ok"]

    report_message("Failed to send goal Slack notification: #{data["error"]} to #{user.slack_uid}")
    false
  end

  def deliver_email(user, goal, notification)
    recipient_email = user.email_addresses.order(:id).pick(:email)
    return false if recipient_email.blank?

    GoalMailer.goal_about_to_miss(
      user,
      goal,
      recipient_email: recipient_email,
      tracked_seconds: notification.tracked_seconds,
      remaining_seconds: notification.remaining_seconds
    ).deliver_now

    true
  end
end
