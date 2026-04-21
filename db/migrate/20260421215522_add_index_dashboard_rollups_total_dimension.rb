class AddIndexDashboardRollupsTotalDimension < ActiveRecord::Migration[8.1]
  def change
    add_index :dashboard_rollups, :dimension,
      name: "index_dashboard_rollups_on_dimension_total",
      where: "dimension = 'total' AND total_seconds > 0"
  end
end
