class HeartbeatImportSource < ApplicationRecord
  require "uri"
  require "resolv"
  require "ipaddr"

  BLOCKED_IP_RANGES = [
    IPAddr.new("0.0.0.0/8"),
    IPAddr.new("10.0.0.0/8"),
    IPAddr.new("100.64.0.0/10"),
    IPAddr.new("127.0.0.0/8"),
    IPAddr.new("169.254.0.0/16"),
    IPAddr.new("172.16.0.0/12"),
    IPAddr.new("192.0.0.0/24"),
    IPAddr.new("192.0.2.0/24"),
    IPAddr.new("192.168.0.0/16"),
    IPAddr.new("198.18.0.0/15"),
    IPAddr.new("198.51.100.0/24"),
    IPAddr.new("203.0.113.0/24"),
    IPAddr.new("224.0.0.0/4"),
    IPAddr.new("240.0.0.0/4"),
    IPAddr.new("255.255.255.255/32"),
    IPAddr.new("::1/128"),
    IPAddr.new("fc00::/7"),
    IPAddr.new("fe80::/10"),
    IPAddr.new("ff00::/8")
  ].freeze

  belongs_to :user

  encrypts :encrypted_api_key, deterministic: false

  enum :provider, {
    wakatime_compatible: 0
  }

  enum :status, {
    idle: 0,
    backfilling: 1,
    syncing: 2,
    paused: 3,
    failed: 4
  }

  validates :provider, presence: true
  validates :endpoint_url, presence: true
  validates :encrypted_api_key, presence: true,
    format: { with: /\A(waka_)?[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i,
              message: "must be a valid UUID, optionally prefixed with waka_",
              allow_blank: true }
  validates :user_id, uniqueness: true
  validate :validate_endpoint_url

  before_validation :normalize_endpoint_url

  def client
    WakatimeCompatibleClient.new(endpoint_url:, api_key: encrypted_api_key)
  end

  def reset_backfill!
    update!(
      status: :idle,
      backfill_cursor_date: nil,
      last_synced_at: nil,
      last_error_message: nil,
      last_error_at: nil,
      consecutive_failures: 0
    )
  end

  private

  def normalize_endpoint_url
    self.endpoint_url = endpoint_url.to_s.strip.sub(%r{/*\z}, "")
  end

  def validate_endpoint_url
    return if endpoint_url.blank?

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
    end

    validate_endpoint_ip
  rescue URI::InvalidURIError
    errors.add(:endpoint_url, "is invalid")
  end

  def validate_endpoint_ip
    uri = URI.parse(endpoint_url)
    hostname = uri.host
    return if hostname.blank?

    disallowed = %w[hackatime.hackclub.com www.hackatime.hackclub.com localhost 127.0.0.1]
    default_host = Rails.application.config.action_mailer.default_url_options&.dig(:host)
    disallowed << default_host.to_s.downcase if default_host.present?

    if disallowed.include?(hostname.downcase)
      errors.add(:endpoint_url, "cannot target this Hackatime host")
      return
    end

    addresses = Resolv.getaddresses(hostname)
    addresses.each do |addr_str|
      ip = IPAddr.new(addr_str)
      if BLOCKED_IP_RANGES.any? { |range| range.include?(ip) }
        errors.add(:endpoint_url, "resolves to a blocked IP address")
        return
      end
    end
  rescue Resolv::ResolvError, URI::InvalidURIError
    # DNS resolution may fail during validation; allow it and let runtime catch it
  end
end
