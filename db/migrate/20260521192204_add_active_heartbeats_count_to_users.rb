class AddActiveHeartbeatsCountToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :active_heartbeats_count, :bigint
    add_column :users, :active_heartbeats_count_backfilled, :boolean, null: false, default: false
  end
end
