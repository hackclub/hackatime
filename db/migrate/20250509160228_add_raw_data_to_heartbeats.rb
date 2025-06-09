class AddRawDataToHeartbeats < ActiveRecord::Migration[8.0]
  def change
    add_column :heartbeats, :raw_data, :jsonb
  end
end
