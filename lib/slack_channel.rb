class SlackChannel
  def self.find_by_id(id, force_refresh: false)
    cached_name = Rails.cache.fetch("slack_channel_#{id}", expires_in: 1.week, force: force_refresh) do
      response = HTTP.headers(Authorization: "Bearer #{ENV.fetch("SLACK_USER_OAUTH_TOKEN")}").get("https://slack.com/api/conversations.info?channel=#{id}")
      data = JSON.parse(response.body)

      data.dig("channel", "name")
    end

    cached_name
  end
end
