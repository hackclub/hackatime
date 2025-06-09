class SlackCommand::SailorsLogOnOffJob < ApplicationJob
  queue_as :latency_10s

  def perform(slack_uid, slack_channel_id, user_name, response_url, enabled)
    # set preference for the user
    slnp = SailorsLogNotificationPreference.find_or_initialize_by(slack_uid: slack_uid, slack_channel_id: slack_channel_id)
    slnp.enabled = enabled
    slnp.save!

    # invalidate the leaderboard cache
    SailorsLogLeaderboard.where(slack_channel_id: slack_channel_id, deleted_at: nil).update_all(deleted_at: Time.current)

    if enabled
      HTTP.post(response_url, json: {
        response_type: "in_channel",
        text: "@#{user_name} ran `/sailorslog on` to turn on High Seas notifications in this channel. Every time they code an hour on a project, a short message celebrating will be posted to this channel. They will also show on `/sailorslog leaderboard`."
      })
    else
      HTTP.post(response_url, json: {
        response_type: "ephemeral",
        text: ":white_check_mark: Coding notifications have been turned off in this channel."
      })
    end
  end
end
