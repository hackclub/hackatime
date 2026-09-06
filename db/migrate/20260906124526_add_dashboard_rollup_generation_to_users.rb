class AddDashboardRollupGenerationToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :dashboard_rollup_generation, :bigint, null: false, default: 0
  end
end
