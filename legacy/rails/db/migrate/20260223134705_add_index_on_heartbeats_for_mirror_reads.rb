class AddIndexOnHeartbeatsForMirrorReads < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEX_NAME = "index_heartbeats_on_user_source_id_direct".freeze

  def up
    add_index :heartbeats,
      [ :user_id, :source_type, :id ],
      name: INDEX_NAME,
      where: "(source_type = 0 AND deleted_at IS NULL)",
      algorithm: :concurrently,
      if_not_exists: true
  end

  def down
    remove_index :heartbeats, name: INDEX_NAME, algorithm: :concurrently
  end
end
