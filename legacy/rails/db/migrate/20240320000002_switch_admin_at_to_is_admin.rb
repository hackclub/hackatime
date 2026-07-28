class SwitchAdminAtToIsAdmin < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :is_admin, :boolean, default: false, null: false

    # Copy data from admin_at to is_admin
    User.reset_column_information
    User.where.not(admin_at: nil).update_all(is_admin: true)

    remove_column :users, :admin_at
  end
end
