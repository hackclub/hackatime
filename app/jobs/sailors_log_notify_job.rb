class SailorsLogNotifyJob < ApplicationJob
  queue_as :latency_10s

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> { "sailors_log_notify_job_#{arguments.first}" },
    drop: true
  )

  def perform(sailors_log_slack_notification_id)
    slsn = SailorsLogSlackNotification.find(sailors_log_slack_notification_id)

    slack_uid = slsn.slack_uid
    slack_channel_id = slsn.slack_channel_id
    project_name = slsn.project_name
    project_duration = slsn.project_duration

    kudos_message = [
      "Great work!",
      "Nice job!",
      "Amazing!",
      "Fantastic!",
      "Excellent!",
      "Awesome!",
      "Well done!",
      "Wahoo!",
      "Way to go!"
    ].sample

    hours = project_duration / 3600

    username = SlackUsername.find_by_uid(slack_uid)
    handle = username.blank? ? "<@#{slack_uid}>" : "@#{username}"

    message = ":boat: `#{handle}` just coded 1 more hour on *#{project_name}* (total: #{hours}hrs). _#{kudos_message}_"

    response = HTTP.auth("Bearer #{ENV['SAILORS_LOG_SLACK_BOT_OAUTH_TOKEN']}")
      .post("https://slack.com/api/chat.postMessage",
            json: {
              channel: slack_channel_id,
              text: message
            })

    response_data = JSON.parse(response.body)
    if response_data["ok"]
      slsn.update(sent: true)
      SailorsLogTeletypeJob.perform_later(message)
    else
      report_message("Failed to send Slack notification: #{response_data["error"]}")
      permanent_channel_errors = %w[channel_not_found is_archived]
      transient_channel_errors = %w[no_permission not_in_channel restricted_action]
      if permanent_channel_errors.include?(response_data["error"])
        SailorsLogNotificationPreference.where(slack_channel_id: slack_channel_id).destroy_all
      elsif transient_channel_errors.include?(response_data["error"])
        SailorsLogNotificationPreference.where(slack_channel_id: slack_channel_id).update_all(enabled: false)
      else
        throw "Failed to send Slack notification: #{response_data["error"]} in #{slack_channel_id}"
      end
    end
  end
end
