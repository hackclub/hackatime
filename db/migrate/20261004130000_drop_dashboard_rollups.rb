# Dashboard rollups now live in ClickHouse (heartbeat_rollups).
class DropDashboardRollups < ActiveRecord::Migration[8.1]
  def change
    drop_table :dashboard_rollups do |t|
      t.text :bucket_value, default: "", null: false
      t.boolean :bucket_value_present, default: true, null: false
      t.string :dimension, null: false
      t.jsonb :payload
      t.integer :source_heartbeats_count
      t.float :source_max_heartbeat_time
      t.integer :total_seconds, default: 0, null: false
      t.references :user, null: false, foreign_key: true, index: true
      t.timestamps
      t.index [ :bucket_value ]
      t.index [ :dimension ], name: "index_dashboard_rollups_on_dimension_total", where: "(((dimension)::text = 'total'::text) AND (total_seconds > 0))"
      t.index [ :user_id, :dimension, :bucket_value_present, :bucket_value ], name: "idx_dashboard_rollups_user_dimension_bucket", unique: true
      t.index [ :user_id, :dimension ]
    end
  end
end
