require "securerandom"

# Issues and validates server-anchored ephemeral nonces backed by Rails.cache (SolidCache)
# to prevent offline backdating of forged multi-week Struggle Window histories.
# When Rails.cache is NullStore (default in test and uncached local dev), falls back to an
# in-process MemoryStore so local testing and CI work without requiring cache config changes.
class StruggleNonceStore
  DEFAULT_TTL = 1.hour

  def self.store
    if Rails.cache.is_a?(ActiveSupport::Cache::NullStore)
      @fallback_memory_store ||= ActiveSupport::Cache::MemoryStore.new
    else
      Rails.cache
    end
  end

  def self.issue(user_id:, ttl: DEFAULT_TTL)
    nonce = SecureRandom.hex(16) # 32 lowercase hex chars
    store.write(cache_key(user_id, nonce), true, expires_in: ttl)
    nonce
  end

  def self.valid?(user_id:, nonce:)
    return false unless nonce.is_a?(String) && nonce.match?(/\A[0-9a-f]{32}\z/)

    store.exist?(cache_key(user_id, nonce))
  end

  def self.clear!
    store.clear
  end

  def self.cache_key(user_id, nonce)
    "hackatime:stp:nonce:#{user_id}:#{nonce}"
  end
  private_class_method :cache_key
end
