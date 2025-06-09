class AddIndexToCommitsUserIdCreatedAt < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :commits, [ :user_id, :created_at ], algorithm: :concurrently
  end
end
