class WakatimeMirror < ApplicationRecord
  require "uri"

  belongs_to :user
  has_many :heartbeats, through: :user

  encrypts :encrypted_api_key, deterministic: false

  validates :endpoint_url, presence: true
  validates :encrypted_api_key, presence: true
  validates :endpoint_url, uniqueness: { scope: :user_id }
  validate :endpoint_url_not_hackatime

  after_create :schedule_initial_sync

  def unsynced_heartbeats
    # Get heartbeats since last sync, or all heartbeats if never synced
    user.heartbeats.where("created_at > ?", last_synced_at || Time.at(0))
  end

  def sync_heartbeats
    return unless encrypted_api_key.present?

    # Get the next batch of heartbeats to sync (max 25 per WakaTime API limit)
    batch = unsynced_heartbeats.limit(25).to_a
    return if batch.empty?

    # Send them all in a single request using the bulk endpoint
    begin
      body = batch.map { |h| h.attributes.slice(*Heartbeat.indexed_attributes) }
      response = HTTP.headers(
        "Authorization" => "Basic #{Base64.strict_encode64(encrypted_api_key + ':')}",
        "Content-Type" => "application/json"
      ).post(
        "#{endpoint_url}/users/current/heartbeats.bulk",
        json: body
      )

      if response.status.success?
        update_column(:last_synced_at, Time.current)
        puts "Successfully synced #{batch.size} heartbeats: #{response.body}"
        # queue another sync job
        WakatimeMirrorSyncJob.perform_later(self)
      else
        Rails.logger.error("Failed to sync heartbeats to #{endpoint_url}: #{response.body}")
      end
    rescue => e
      Rails.logger.error("Error syncing heartbeats to #{endpoint_url}: #{e.message}")
    end
  end

  private

  def endpoint_url_not_hackatime
    return unless endpoint_url.present?

    uri = URI.parse(endpoint_url)
    errors.add(:endpoint_url, "cannot be hackatime.hackclub.com") if uri.host == "hackatime.hackclub.com"
  rescue URI::InvalidURIError
    # other validations will handle invalid URLs
  end

  def schedule_initial_sync
    WakatimeMirrorSyncJob.perform_later(self)
  end
end
