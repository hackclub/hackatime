require "json"
require "securerandom"

# Issues and validates server-anchored ephemeral nonces backed by Rails.cache (SolidCache in
# production) with a 7-day TTL so developers can code completely offline for up to a week and
# auto-sync cleanly upon reconnect. In development (:memory_store), nonces are also mirrored to
# tmp/struggle_nonces.json so local server restarts never invalidate queued offline windows.
class StruggleNonceStore
  DEFAULT_TTL = 7.days
  DEV_STORE_PATH = Rails.root.join("tmp", "struggle_nonces.json")

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
    persist_dev_nonce(user_id, nonce, Time.current.to_i + ttl.to_i) if persist_to_dev_file?
    nonce
  end

  def self.valid?(user_id:, nonce:)
    return false unless nonce.is_a?(String) && nonce.match?(/\A[0-9a-f]{32}\z/)

    return true if store.exist?(cache_key(user_id, nonce))
    return true if persist_to_dev_file? && dev_nonce_valid?(user_id, nonce)

    false
  end

  def self.clear!
    store.clear
    File.delete(DEV_STORE_PATH) if persist_to_dev_file? && File.exist?(DEV_STORE_PATH)
  end

  def self.cache_key(user_id, nonce)
    "hackatime:stp:nonce:#{user_id}:#{nonce}"
  end
  private_class_method :cache_key

  def self.persist_to_dev_file?
    Rails.env.development? && Rails.cache.is_a?(ActiveSupport::Cache::MemoryStore)
  end
  private_class_method :persist_to_dev_file?

  def self.persist_dev_nonce(user_id, nonce, expires_at_unix)
    data = load_dev_nonces
    now = Time.current.to_i
    data.delete_if { |_, exp| exp.to_i <= now }
    data[cache_key(user_id, nonce)] = expires_at_unix
    FileUtils.mkdir_p(DEV_STORE_PATH.dirname)
    File.write(DEV_STORE_PATH, JSON.generate(data))
  rescue StandardError
    nil
  end
  private_class_method :persist_dev_nonce

  def self.dev_nonce_valid?(user_id, nonce)
    exp = load_dev_nonces[cache_key(user_id, nonce)]
    exp.present? && exp.to_i > Time.current.to_i
  end
  private_class_method :dev_nonce_valid?

  def self.load_dev_nonces
    return {} unless File.exist?(DEV_STORE_PATH)

    parsed = JSON.parse(File.read(DEV_STORE_PATH))
    parsed.is_a?(Hash) ? parsed : {}
  rescue StandardError
    {}
  end
  private_class_method :load_dev_nonces
end
