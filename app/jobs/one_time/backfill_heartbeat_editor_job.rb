class OneTime::BackfillHeartbeatEditorJob < ApplicationJob
  queue_as :default

  def perform(dry_run = true)
    puts "Processing heartbeats" if dry_run

    processed_heartbeats = []

    heartbeats_to_categorize.find_each(batch_size: 1000) do |heartbeat|
      parsed_ua = WakatimeService.parse_user_agent(heartbeat.user_agent)
      if parsed_ua[:err].present?
        puts "Error parsing user agent for heartbeat #{heartbeat.id}, user_agent: #{heartbeat.user_agent}, error: #{parsed_ua[:err]}"
        next
      end
      puts "Processing heartbeat #{heartbeat.id}, user_agent: #{heartbeat.user_agent}, editor: #{parsed_ua[:editor]}, os: #{parsed_ua[:os]}" if dry_run
      next if dry_run

      # Store the parsed values for bulk update
      heartbeat.editor = parsed_ua[:editor]
      heartbeat.operating_system = parsed_ua[:os]
      processed_heartbeats << heartbeat

      # When we have 1000 records, update them and clear the array
      if processed_heartbeats.size >= 1000
        bulk_update_heartbeats(processed_heartbeats)
        processed_heartbeats = []
      end
    end

    # Update any remaining records
    unless dry_run && processed_heartbeats.any?
      bulk_update_heartbeats(processed_heartbeats)
    end
  end

  private

  def heartbeats_to_categorize
    Heartbeat.where(editor: nil).where.not(user_agent: nil)
  end

  def bulk_update_heartbeats(heartbeats)
    Heartbeat.import heartbeats,
      on_duplicate_key_update: {
        conflict_target: [ :id ],
        columns: [ :editor, :operating_system, :updated_at ]
      }
  end
end
