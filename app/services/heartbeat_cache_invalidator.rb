class HeartbeatCacheInvalidator
  CACHE_VERSION_TTL = 30.days

  class << self
    def version_for(user_or_id)
      user_id = extract_user_id(user_or_id)
      return 0 if user_id.blank?

      Rails.cache.fetch(version_key(user_id), expires_in: CACHE_VERSION_TTL) { 0 }.to_i
    end

    def bump_for(user_or_id)
      user_id = extract_user_id(user_or_id)
      return 0 if user_id.blank?

      version = version_for(user_id) + 1
      Rails.cache.write(version_key(user_id), version, expires_in: CACHE_VERSION_TTL)
      Rails.cache.delete("user_streak_#{user_id}")
      version
    end

    private

    def extract_user_id(user_or_id)
      user_or_id.respond_to?(:id) ? user_or_id.id : user_or_id
    end

    def version_key(user_id)
      "heartbeat-cache-version:user:#{user_id}"
    end
  end
end
