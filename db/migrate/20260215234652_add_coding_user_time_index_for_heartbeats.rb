class AddCodingUserTimeIndexForHeartbeats < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :heartbeats,
      [ :user_id, :time ],
      where: "(deleted_at IS NULL AND category = 'coding')",
      name: "idx_heartbeats_coding_user_time",
      algorithm: :concurrently
  end
end
