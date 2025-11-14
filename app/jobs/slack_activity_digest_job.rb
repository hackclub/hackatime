class SlackActivityDigestJob < ApplicationJob
  queue_as :latency_5m

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> { "slack_activity_digest_job_#{arguments.first}" }
  )

  def perform(subscription_id, as_of_epoch = nil)
    subscription = SlackActivityDigestSubscription.find_by(id: subscription_id)
    return unless subscription&.enabled?

    as_of = as_of_epoch ? Time.at(as_of_epoch).utc : Time.current

    result = SlackActivityDigestService.new(subscription: subscription, as_of: as_of).build

    deliver(subscription, result)
    subscription.mark_delivered!(as_of)
  end

  private

  def deliver(subscription, result)
    token = ENV["SLACK_ACTIVITY_DIGEST_BOT_TOKEN"]
    raise "Missing SLACK_ACTIVITY_DIGEST_BOT_TOKEN" if token.blank?

    payload = {
      channel: subscription.slack_channel_id,
      text: result.fallback_text,
      blocks: result.blocks
    }

    response = HTTP.auth("Bearer #{token}")
                   .post("https://slack.com/api/chat.postMessage", json: payload)

    body = JSON.parse(response.body)
    if body["ok"] != true
      Rails.logger.error("SlackActivityDigestJob failed for #{subscription.slack_channel_id}: #{body['error'] || 'unknown error'}")
      raise "Slack API error: #{body['error'] || 'unknown error'}"
    end
  rescue StandardError => e
    Rails.logger.error("SlackActivityDigestJob encountered error: #{e.message}")
    raise
  end
end
