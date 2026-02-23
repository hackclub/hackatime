class UpdateAirtableUserDataJob < ApplicationJob
  queue_as :latency_5m

  Table = Norairrecord.table(ENV["cccccbceufnn"], "app6VcLJoYFbDdGWK", "tblnzmotZ55MFBfV4")

  def perform
    users_with_heartbeats.includes(:email_addresses).find_in_batches(batch_size: 100) do |batch|
      records = []

      # Efficiently calculate total coding seconds for all users in this batch
      user_ids_in_batch = batch.map(&:id)
      total_coding_seconds_per_user = Heartbeat
                                        .where(user_id: user_ids_in_batch)
                                        .coding_only # Only count "coding" category
                                        .with_valid_timestamps
                                        .group(:user_id) # Group by user
                                        .duration_seconds # Returns a hash { user_id => seconds }

      batch.each do |user|
        first_heartbeat_time = user.heartbeats.with_valid_timestamps.order(time: :asc).limit(1).pluck(:time).first
        first_direct_heartbeat_time = user.heartbeats.direct_entry.with_valid_timestamps.order(time: :asc).limit(1).pluck(:time).first
        first_test_heartbeat_time = user.heartbeats.test_entry.with_valid_timestamps.order(time: :asc).limit(1).pluck(:time).first
        created_at = user.created_at.to_i
        next if first_heartbeat_time.nil? || first_heartbeat_time > Time.now.to_f

        # Get the pre-calculated total coding seconds for this user
        user_total_coding_seconds = total_coding_seconds_per_user[user.id] || 0
        total_minutes_logged = (user_total_coding_seconds / 60).to_i

        user.email_addresses.map do |email_address|
          records << Table.new({
            email: email_address.email,
            signed_up_at: Time.at(created_at).iso8601,
            first_direct_heartbeat_time: first_direct_heartbeat_time ? Time.at(first_direct_heartbeat_time.to_f).iso8601 : nil,
            first_test_heartbeat_time: first_test_heartbeat_time ? Time.at(first_test_heartbeat_time.to_f).iso8601 : nil,
            first_heartbeat_time: Time.at(first_heartbeat_time.to_f).iso8601, # airtable expects milliseconds
            total_minutes_logged: total_minutes_logged # Add the new field here
          })
        end
      end

      # Only attempt to upsert if there are records to process
      Table.batch_upsert(records, "email") if records.any?
    end
  end

  private

  def users_with_heartbeats
    User.where(id: Heartbeat.with_valid_timestamps.distinct.pluck(:user_id))
  end
end
