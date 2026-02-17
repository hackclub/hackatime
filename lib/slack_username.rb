class SlackUsername
  def self.find_by_uid(uid)
    key = "slack_username_#{uid}"

    cached_name = Rails.cache.fetch(key, expires_in: 1.day) do
      response = HTTP.headers(Authorization: "Bearer #{ENV.fetch("SLACK_USER_OAUTH_TOKEN")}").get("https://slack.com/api/users.info?user=#{uid}")
      data = JSON.parse(response.body)

      name = data.dig("user", "profile", "display_name")
      name ||= data.dig("user", "profile", "display_name_normalized")

      name
    end

    Rails.cache.delete(key) unless cached_name.present?

    cached_name
  end
end
