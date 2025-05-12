class WakatimeMirror < ApplicationRecord
  belongs_to :user
  has_many :heartbeats, through: :user

  encrypts :encrypted_api_key, deterministic: false

  validates :endpoint_url, presence: true
  validates :encrypted_api_key, presence: true
  validates :endpoint_url, uniqueness: { scope: :user_id }

  after_create :schedule_initial_sync

  def unsynced_heartbeats
    # For testing: sync the 100 most recent heartbeats
    heartbeats.order(time: :desc).limit(100)
  end

  def sync_heartbeats
    return unless encrypted_api_key.present?

    # Get the next batch of heartbeats to sync (max 25 per WakaTime API limit)
    batch = unsynced_heartbeats.limit(25).to_a
    return if batch.empty?

    # Print timestamps of heartbeats being synced
    puts "\nSyncing heartbeats:"
    batch.each do |h|
      puts "  #{Time.at(h.time).strftime('%Y-%m-%d %H:%M:%S')} - #{h.entity}"
    end
    puts ""

    # Send them all in a single request using the bulk endpoint
    begin
      response = HTTP.headers(
        "Authorization" => "Basic #{Base64.strict_encode64(encrypted_api_key + ':')}",
        "Content-Type" => "application/json"
      ).post(
        "#{endpoint_url}/users/current/heartbeats.bulk",
        json: batch.map { |h| h.attributes.slice(
          :branch,
          :category,
          :dependencies,
          :editor,
          :entity,
          :language,
          :machine,
          :operating_system,
          :project,
          :type,
          :user_agent,
          :line_additions,
          :line_deletions,
          :lineno,
          :lines,
          :cursorpos,
          :project_root_count,
          :time,
          :is_write
        ) }
      )

      if response.status.success?
        update_column(:last_synced_at, Time.current)
      else
        Rails.logger.error("Failed to sync heartbeats to #{endpoint_url}: #{response.body}")
      end
    rescue => e
      Rails.logger.error("Error syncing heartbeats to #{endpoint_url}: #{e.message}")
    end
  end

  private

  def schedule_initial_sync
    WakatimeMirrorSyncJob.perform_later(self)
  end
end
