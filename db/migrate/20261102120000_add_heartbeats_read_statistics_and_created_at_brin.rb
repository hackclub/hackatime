class AddHeartbeatsReadStatisticsAndCreatedAtBrin < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    # Sailor's Log polls heartbeats created in the last minutes; created_at follows insertion order, so a BRIN index
    # of a few hundred kB replaces a full table scan.
    add_index :heartbeats, :created_at, using: :brin, name: "index_heartbeats_on_created_at_brin",
      algorithm: :concurrently, if_not_exists: true

    # The admin machine/IP queries group by these columns; without combined distinct counts the planner expects
    # about a million groups instead of tens of thousands and skips parallel aggregation.
    execute <<~SQL
      CREATE STATISTICS IF NOT EXISTS heartbeats_user_machine_ip_ndistinct (ndistinct)
        ON user_id, machine, ip_address FROM heartbeats
    SQL
    execute "CREATE STATISTICS IF NOT EXISTS heartbeats_machine_user_ndistinct (ndistinct) ON machine, user_id FROM heartbeats"
    execute "ANALYZE heartbeats"
  end

  def down
    execute "DROP STATISTICS IF EXISTS heartbeats_machine_user_ndistinct"
    execute "DROP STATISTICS IF EXISTS heartbeats_user_machine_ip_ndistinct"
    remove_index :heartbeats, name: "index_heartbeats_on_created_at_brin", algorithm: :concurrently, if_exists: true
  end
end
