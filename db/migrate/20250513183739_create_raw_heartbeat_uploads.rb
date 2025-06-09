class CreateRawHeartbeatUploads < ActiveRecord::Migration[8.0]
  def change
    create_table :raw_heartbeat_uploads do |t|
      t.jsonb :request_headers, null: false
      t.jsonb :request_body, null: false

      t.timestamps
    end
  end
end
