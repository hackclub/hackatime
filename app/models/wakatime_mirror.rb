class WakatimeMirror < ApplicationRecord
  require "uri"

  belongs_to :user

  encrypts :encrypted_api_key, deterministic: false

  attr_accessor :request_host

  validates :endpoint_url, presence: true
  validates :encrypted_api_key, presence: true
  validates :endpoint_url, uniqueness: { scope: :user_id }
  validate :validate_endpoint_url

  before_validation :normalize_endpoint_url
  before_create :initialize_last_synced_heartbeat_id

  scope :active, -> { where(enabled: true) }

  def direct_heartbeats_after(heartbeat_id)
    user.heartbeats.where(source_type: :direct_entry).where("id > ?", heartbeat_id.to_i).order(id: :asc)
  end

  def post_heartbeats(payload)
    HTTP.timeout(connect: 5, read: 30, write: 10)
      .headers(
        "Authorization" => "Basic #{Base64.strict_encode64("#{encrypted_api_key}:")}",
        "Content-Type" => "application/json"
      )
      .post("#{endpoint_url}/users/current/heartbeats.bulk", json: payload)
  end

  def clear_error_state!
    update!(
      last_error_message: nil,
      last_error_at: nil,
      consecutive_failures: 0
    )
  end

  def record_transient_failure!(message)
    update!(
      status_payload_for_failure(message, keep_enabled: true)
    )
  end

  def mark_auth_failed!(message)
    update!(
      status_payload_for_failure(message, keep_enabled: false)
    )
  end

  def mark_failed!(message)
    update!(
      status_payload_for_failure(message, keep_enabled: enabled)
    )
  end

  private

  def initialize_last_synced_heartbeat_id
    self.last_synced_heartbeat_id ||= user.heartbeats.maximum(:id)
  end

  def normalize_endpoint_url
    self.endpoint_url = endpoint_url.to_s.strip.sub(%r{/*\z}, "")
  end

  def validate_endpoint_url
    return unless endpoint_url.present?

    uri = URI.parse(endpoint_url)
    unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      errors.add(:endpoint_url, "must be an HTTP or HTTPS URL")
      return
    end

    if uri.host.blank?
      errors.add(:endpoint_url, "must include a host")
      return
    end

    if !Rails.env.development? && uri.scheme != "https"
      errors.add(:endpoint_url, "must use https")
      return
    end

    if disallowed_hosts.include?(uri.host.downcase)
      errors.add(:endpoint_url, "cannot target this Hackatime host")
    end
  rescue URI::InvalidURIError
    errors.add(:endpoint_url, "is invalid")
  end

  def disallowed_hosts
    hosts = %w[hackatime.hackclub.com www.hackatime.hackclub.com localhost 127.0.0.1]
    hosts << request_host.to_s.downcase if request_host.present?
    default_host = Rails.application.config.action_mailer.default_url_options&.dig(:host)
    hosts << default_host.to_s.downcase if default_host.present?
    hosts.uniq
  end

  def status_payload_for_failure(message, keep_enabled:)
    {
      enabled: keep_enabled,
      last_error_message: message.to_s.truncate(500),
      last_error_at: Time.current,
      consecutive_failures: consecutive_failures.to_i + 1
    }
  end
end
