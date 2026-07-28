class MigrateAdminLevelsOnUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :admin_level, :integer, default: 0, null: false

    User.reset_column_information
    User.find_each do |user|
      if user.is_superadmin
        user.update_column(:admin_level, 1)
      elsif user.is_admin
        user.update_column(:admin_level, 2)
      else
        user.update_column(:admin_level, 0)
      end
    end

    remove_column :users, :is_admin, :boolean
    remove_column :users, :is_superadmin, :boolean
  end

  def down
    add_column :users, :is_admin, :boolean, default: false, null: false
    add_column :users, :is_superadmin, :boolean, default: false, null: false

    User.reset_column_information
    User.find_each do |user|
      case user.admin_level
      when 1
        user.update_column(:is_superadmin, true)
        user.update_column(:is_admin, true)
      when 2
        user.update_column(:is_admin, true)
        user.update_column(:is_superadmin, false)
      else
        user.update_column(:is_admin, false)
        user.update_column(:is_superadmin, false)
      end
    end

    remove_column :users, :admin_level, :integer
  end
end
