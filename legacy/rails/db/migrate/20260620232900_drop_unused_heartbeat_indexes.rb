class DropUnusedHeartbeatIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    remove_index :heartbeats,
      name: :index_heartbeats_on_time_imported,
      algorithm: :concurrently,
      if_exists: true

    remove_index :heartbeats,
      name: :index_heartbeats_on_last_language_user_id,
      algorithm: :concurrently,
      if_exists: true
  end

  def down
    add_index :heartbeats, :time,
      name: :index_heartbeats_on_time_imported,
      where: "source_type != 0",
      algorithm: :concurrently,
      if_not_exists: true

    add_index :heartbeats, :user_id,
      name: :index_heartbeats_on_last_language_user_id,
      where: "language = '<<LAST_LANGUAGE>>'",
      algorithm: :concurrently,
      if_not_exists: true
  end
end
