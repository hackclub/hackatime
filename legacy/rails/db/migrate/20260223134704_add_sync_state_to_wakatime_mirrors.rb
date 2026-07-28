class AddSyncStateToWakatimeMirrors < ActiveRecord::Migration[8.1]
  def change
    add_column :wakatime_mirrors, :enabled, :boolean, null: false, default: true
    add_column :wakatime_mirrors, :last_synced_heartbeat_id, :bigint
    add_column :wakatime_mirrors, :last_error_message, :text
    add_column :wakatime_mirrors, :last_error_at, :datetime
    add_column :wakatime_mirrors, :consecutive_failures, :integer, null: false, default: 0
  end
end
