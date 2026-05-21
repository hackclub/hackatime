class CreateDashboardRollups < ActiveRecord::Migration[8.1]
  def change
    create_table :dashboard_rollups do |t|
      t.references :user, null: false, foreign_key: true
      t.string :dimension, null: false
      t.text :bucket_value, null: false, default: ""
      t.boolean :bucket_value_present, null: false, default: true
      t.integer :total_seconds, null: false, default: 0
      t.integer :source_heartbeats_count
      t.float :source_max_heartbeat_time
      t.timestamps
    end

    add_index :dashboard_rollups, [ :user_id, :dimension ]
    add_index :dashboard_rollups,
              [ :user_id, :dimension, :bucket_value_present, :bucket_value ],
              unique: true,
              name: "idx_dashboard_rollups_user_dimension_bucket"
  end
end
