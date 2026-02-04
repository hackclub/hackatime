class DropAhoyTables < ActiveRecord::Migration[8.0]
  def up
    drop_table :ahoy_events, if_exists: true
    drop_table :ahoy_visits, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
