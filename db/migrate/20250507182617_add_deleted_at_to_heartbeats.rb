class AddDeletedAtToHeartbeats < ActiveRecord::Migration[8.0]
  def change
    add_column :heartbeats, :deleted_at, :datetime
  end
end
