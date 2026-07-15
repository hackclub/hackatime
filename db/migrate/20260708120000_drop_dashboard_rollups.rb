class DropDashboardRollups < ActiveRecord::Migration[8.1]
  def up
    drop_table :dashboard_rollups, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
