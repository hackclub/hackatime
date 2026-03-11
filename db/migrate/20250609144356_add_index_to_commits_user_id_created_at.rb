class AddIndexToCommitsUserIdCreatedAt < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :commits, [ :user_id, :created_at ], algorithm: :concurrently
  end
end
