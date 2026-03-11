class AddDeletedAtToHeartbeats < ActiveRecord::Migration[8.1]
  def change
    add_column :heartbeats, :deleted_at, :datetime
  end
end
