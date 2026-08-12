class AddDashboardRollupGenerationsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :dashboard_rollup_generation, :bigint, null: false, default: 0
    add_column :users, :dashboard_rollup_refreshed_generation, :bigint, null: false, default: 0
    add_index :users, :id,
      where: "dashboard_rollup_generation > dashboard_rollup_refreshed_generation",
      name: "index_users_with_dirty_dashboard_rollups"
  end
end
