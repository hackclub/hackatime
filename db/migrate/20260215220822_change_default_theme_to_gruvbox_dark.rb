class ChangeDefaultThemeToGruvboxDark < ActiveRecord::Migration[8.0]
  def up
    return unless column_exists?(:users, :theme)

    change_column_default :users, :theme, from: 0, to: 4
  end

  def down
    return unless column_exists?(:users, :theme)

    change_column_default :users, :theme, from: 4, to: 0
  end
end
