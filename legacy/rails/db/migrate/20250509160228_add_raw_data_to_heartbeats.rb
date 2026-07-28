class AddRawDataToHeartbeats < ActiveRecord::Migration[8.1]
  def change
    add_column :heartbeats, :raw_data, :jsonb
  end
end
