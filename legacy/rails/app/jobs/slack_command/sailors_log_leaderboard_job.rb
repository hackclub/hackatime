class SlackCommand::SailorsLogLeaderboardJob < ApplicationJob
  queue_as :latency_10s
  include ApplicationHelper

  def perform(slack_uid, channel_id, response_url)
    # Send loading message first
    loading_messages = FlavorText.loading_messages + FlavorText.rare_loading_messages + FlavorText.slack_loading_messages
    response = HTTP.post(response_url, json: {
      response_type: "ephemeral",
      text: ":beachball: #{loading_messages.sample}"
    })

    Rails.logger.info "[SailorsLogLeaderboardJob] Performing leaderboard for channel #{channel_id}, user #{slack_uid}"
    # either find a leaderboard for this channel from the last 1 minute or create a new one
    leaderboard = SailorsLogLeaderboard.where(slack_channel_id: channel_id, deleted_at: nil)
                                       .where("created_at > ?", 1.minute.ago)
                                       .order(created_at: :desc)
                                       .first

    # Create new leaderboard if none found
    leaderboard ||= SailorsLogLeaderboard.create!(
      slack_channel_id: channel_id,
      slack_uid: slack_uid
    )

    # Send final message
    response = HTTP.post(response_url, json: {
      response_type: "ephemeral",
      replace_original: true,
      text: leaderboard.message
    })

    Rails.logger.info "[SailorsLogLeaderboardJob] Response: #{response.body}"

  rescue => e
    Rails.logger.error "[SailorsLogLeaderboardJob] Error: #{e.message}"
    Rails.logger.error "[SailorsLogLeaderboardJob] Backtrace: #{e.backtrace.join("\n")}"
    response = HTTP.post(response_url, json: {
      response_type: "ephemeral",
      text: "Error: #{e.message}"
    })

    Rails.logger.info "[SailorsLogLeaderboardJob] Response: #{response.body}"
  end
end
