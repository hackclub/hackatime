class OneTime::RecalcHeartbeatFieldHashJob < ApplicationJob
  queue_as :default

  def perform
    Heartbeat.find_each(batch_size: 2500) do |heartbeat|
      begin
        heartbeat.send(:set_fields_hash!)
        heartbeat.save!
      rescue ActiveRecord::RecordNotUnique
        # If we have a duplicate fields_hash, soft delete this record
        heartbeat.soft_delete
      end
    end
  end
end
