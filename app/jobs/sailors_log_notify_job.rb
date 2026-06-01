class SailorsLogNotifyJob < ApplicationJob
  queue_as :latency_10s

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1, key: -> { "sailors_log_notify_job_#{arguments.first}" }
  )

  KUDOS = [ "Great work!", "Nice job!", "Amazing!", "Fantastic!", "Excellent!",
            "Awesome!", "Well done!", "Wahoo!", "Way to go!" ].freeze
  REMOVABLE_CHANNEL_ERRORS = %w[channel_not_found is_archived no_permission not_in_channel restricted_action].freeze

  def perform(sailors_log_slack_notification_id)
    slsn = SailorsLogSlackNotification.find(sailors_log_slack_notification_id)
    hours = slsn.project_duration / 3600
    username = SlackUsername.find_by_uid(slsn.slack_uid)
    handle = username.blank? ? "<@#{slsn.slack_uid}>" : "@#{username}"
    message = ":boat: `#{handle}` just coded 1 more hour on *#{slsn.project_name}* (total: #{hours}hrs). _#{KUDOS.sample}_"

    response = HTTP.auth("Bearer #{ENV['SAILORS_LOG_SLACK_BOT_OAUTH_TOKEN']}")
      .post("https://slack.com/api/chat.postMessage",
            json: { channel: slsn.slack_channel_id, text: message })

    data = JSON.parse(response.body)
    if data["ok"]
      slsn.update(sent: true)
    else
      report_message("Failed to send Slack notification: #{data["error"]}")
      if REMOVABLE_CHANNEL_ERRORS.include?(data["error"])
        SailorsLogNotificationPreference.where(slack_channel_id: slsn.slack_channel_id).destroy_all
      else
        raise "Failed to send Slack notification: #{data["error"]} in #{slsn.slack_channel_id}"
      end
    end
  end
end
