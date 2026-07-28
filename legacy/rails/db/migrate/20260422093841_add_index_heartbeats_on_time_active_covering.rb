class AddIndexHeartbeatsOnTimeActiveCovering < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :heartbeats, :time,
      name: "index_heartbeats_on_time_active_covering",
      where: "deleted_at IS NULL",
      include: [ :source_type ],
      algorithm: :concurrently,
      if_not_exists: true
  end
end
