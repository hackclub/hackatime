class AddAdminAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :admin_at, :datetime
  end
end
