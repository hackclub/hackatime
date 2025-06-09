class AddRawHeartbeatUploadToHeartbeats < ActiveRecord::Migration[8.0]
  def change
    add_reference :heartbeats, :raw_heartbeat_upload, null: true, foreign_key: true
  end
end
