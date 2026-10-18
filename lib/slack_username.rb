class SlackUsername
  def self.find_by_uid(uid)
    key = "slack_username_#{uid}"

    cached_name = Rails.cache.fetch(key, expires_in: 1.day) do
      data = Cachet.user(uid)

      data && (data["displayName"].presence || data["realName"].presence)
    end

    Rails.cache.delete(key) unless cached_name.present?

    cached_name
  end
end
