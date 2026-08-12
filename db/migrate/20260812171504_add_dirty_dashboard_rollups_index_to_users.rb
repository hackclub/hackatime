class AddDirtyDashboardRollupsIndexToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :users, :id,
      where: "dashboard_rollup_generation > dashboard_rollup_refreshed_generation",
      name: "index_users_with_dirty_dashboard_rollups",
      algorithm: :concurrently,
      if_not_exists: true
  end
end
