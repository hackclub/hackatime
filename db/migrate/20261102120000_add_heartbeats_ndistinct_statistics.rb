class AddHeartbeatsNdistinctStatistics < ActiveRecord::Migration[8.1]
  # The admin machine/IP queries group by these columns; without combined distinct counts the planner expects
  # about a million groups instead of tens of thousands and skips parallel aggregation.
  def up
    execute <<~SQL
      CREATE STATISTICS IF NOT EXISTS heartbeats_user_machine_ip_ndistinct (ndistinct)
        ON user_id, machine, ip_address FROM heartbeats
    SQL
    execute "CREATE STATISTICS IF NOT EXISTS heartbeats_machine_user_ndistinct (ndistinct) ON machine, user_id FROM heartbeats"
  end

  def down
    execute "DROP STATISTICS IF EXISTS heartbeats_machine_user_ndistinct"
    execute "DROP STATISTICS IF EXISTS heartbeats_user_machine_ip_ndistinct"
  end
end
