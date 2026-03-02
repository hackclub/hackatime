class HeartbeatImportSource < ApplicationRecord
  require "uri"

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
  validates :encrypted_api_key, presence: true
  validates :user_id, uniqueness: true
  validate :validate_endpoint_url
  validate :validate_backfill_range

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

  def validate_backfill_range
    return unless initial_backfill_start_date.present? && initial_backfill_end_date.present?
    return unless initial_backfill_start_date > initial_backfill_end_date

    errors.add(:initial_backfill_end_date, "must be on or after the start date")
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
  rescue URI::InvalidURIError
    errors.add(:endpoint_url, "is invalid")
  end
end
