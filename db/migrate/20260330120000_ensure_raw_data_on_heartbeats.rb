class EnsureRawDataOnHeartbeats < ActiveRecord::Migration[8.1]
  def change
    add_column :heartbeats, :raw_data, :jsonb, if_not_exists: true
  end
end
