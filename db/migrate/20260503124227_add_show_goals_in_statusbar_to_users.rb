class AddShowGoalsInStatusbarToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :show_goals_in_statusbar, :boolean, default: true, null: false
  end
end
