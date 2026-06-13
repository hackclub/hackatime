class AddPayloadToDashboardRollups < ActiveRecord::Migration[8.1]
  def change
    add_column :dashboard_rollups, :payload, :jsonb
  end
end
