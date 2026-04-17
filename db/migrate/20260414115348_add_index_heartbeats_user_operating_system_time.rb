class AddIndexHeartbeatsUserOperatingSystemTime < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :heartbeats, [ :user_id, :operating_system, :time ],
              name: :idx_heartbeats_user_operating_system_time,
              where: "deleted_at IS NULL",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
