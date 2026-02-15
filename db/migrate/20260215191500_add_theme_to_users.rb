class AddThemeToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :theme, :integer, default: 0, null: false, if_not_exists: true
  end
end
