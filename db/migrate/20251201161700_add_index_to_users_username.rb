class AddIndexToUsersUsername < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :users, :username, algorithm: :concurrently
  end
end
