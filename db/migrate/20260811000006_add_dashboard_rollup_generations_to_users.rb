class AddDashboardRollupGenerationsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :dashboard_rollup_generation, :bigint, null: false, default: 0
    add_column :users, :dashboard_rollup_refreshed_generation, :bigint, null: false, default: 0
  end
end
