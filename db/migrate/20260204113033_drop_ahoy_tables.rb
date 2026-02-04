class DropAhoyTables < ActiveRecord::Migration[8.0]
  def up
    drop_table :ahoy_events if table_exists?(:ahoy_events)
    drop_table :ahoy_visits if table_exists?(:ahoy_visits)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
