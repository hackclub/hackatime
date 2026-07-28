class AddIndexToHeartbeatsProject < ActiveRecord::Migration[8.1]
  # this is what i got from stackoverflow
  disable_ddl_transaction!

  def change
    add_index :heartbeats, :project, algorithm: :concurrently
    add_index :heartbeats, [ :project, :time ], algorithm: :concurrently
  end
end
