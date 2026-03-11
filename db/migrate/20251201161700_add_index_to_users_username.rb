class AddIndexToUsersUsername < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :users, :username, algorithm: :concurrently
  end
end
