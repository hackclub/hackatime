class UpdateAirtableUserDataJob < ApplicationJob
  queue_as :latency_5m

  Table = Norairrecord.table(ENV["LOOPS_AIRTABLE_PAT"], "app6VcLJoYFbDdGWK", "tblnzmotZ55MFBfV4")

  def perform
    users_with_heartbeats.includes(:email_addresses).find_in_batches(batch_size: 100) do |batch|
      records = []
      total_coding_seconds = Heartbeat.where(user_id: batch.map(&:id)).coding_only
        .with_valid_timestamps.group(:user_id).duration_seconds

      batch.each do |user|
        first_heartbeat_time = user.heartbeats.with_valid_timestamps.order(time: :asc).limit(1).pick(:time)
        next if first_heartbeat_time.nil? || first_heartbeat_time > Time.now.to_f

        first_direct_heartbeat_time = user.heartbeats.direct_entry.with_valid_timestamps.order(time: :asc).limit(1).pick(:time)
        first_test_heartbeat_time = user.heartbeats.test_entry.with_valid_timestamps.order(time: :asc).limit(1).pick(:time)
        total_minutes_logged = ((total_coding_seconds[user.id] || 0) / 60).to_i

        user.email_addresses.each do |email_address|
          records << Table.new(
            email: email_address.email,
            signed_up_at: Time.at(user.created_at.to_i).iso8601,
            first_direct_heartbeat_time: first_direct_heartbeat_time ? Time.at(first_direct_heartbeat_time.to_f).iso8601 : nil,
            first_test_heartbeat_time: first_test_heartbeat_time ? Time.at(first_test_heartbeat_time.to_f).iso8601 : nil,
            first_heartbeat_time: Time.at(first_heartbeat_time.to_f).iso8601,
            total_minutes_logged: total_minutes_logged
          )
        end
      end

      Table.batch_upsert(records, "email") if records.any?
    end
  end

  private

  def users_with_heartbeats
    User.where(id: Heartbeat.with_valid_timestamps.distinct.pluck(:user_id))
  end
end
