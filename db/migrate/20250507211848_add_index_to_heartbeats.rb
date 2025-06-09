class AddIndexToHeartbeats < ActiveRecord::Migration[8.0]
  def change
    add_index :heartbeats, [ :user_id, :time ],
              name: "idx_heartbeats_user_time_active",
              where: "deleted_at IS NULL",
              if_not_exists: true
  end
end
