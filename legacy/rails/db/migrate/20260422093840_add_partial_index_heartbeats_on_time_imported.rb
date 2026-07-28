class AddPartialIndexHeartbeatsOnTimeImported < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :heartbeats, :time,
      name: "index_heartbeats_on_time_imported",
      where: "source_type != 0",
      algorithm: :concurrently,
      if_not_exists: true
  end
end
