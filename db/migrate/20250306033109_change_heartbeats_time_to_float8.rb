class ChangeHeartbeatsTimeToFloat8 < ActiveRecord::Migration[8.1]
  def change
    change_column :heartbeats, :time, :float8, null: false
  end
end
