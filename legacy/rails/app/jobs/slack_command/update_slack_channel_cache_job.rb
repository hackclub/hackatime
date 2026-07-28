class SlackCommand::UpdateSlackChannelCacheJob < ApplicationJob
  queue_as :latency_5m

  def perform
    channels = SailorsLogNotificationPreference.where(enabled: true).distinct.pluck(:slack_channel_id)

    Rails.logger.info("Updating slack channel cache for #{channels.count} channels")
    channels.each do |channel_id|
      sleep 2 # slack rate limit is 50 per minute
      Rails.logger.info("Updating slack channel cache for #{channel_id}")
      SlackChannel.find_by_id(channel_id, force_refresh: true)
    end
  end
end
