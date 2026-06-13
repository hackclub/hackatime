class ChangeDefaultThemeToRose < ActiveRecord::Migration[8.1]
  def up
    return unless column_exists?(:users, :theme)

    change_column_default :users, :theme, from: 4, to: 8
  end

  def down
    return unless column_exists?(:users, :theme)

    change_column_default :users, :theme, from: 8, to: 4
  end
end
