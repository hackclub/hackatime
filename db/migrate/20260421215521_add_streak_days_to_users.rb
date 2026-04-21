class AddStreakDaysToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :streak_days, :integer, default: 0, null: false
    add_column :users, :streak_updated_at, :datetime

    add_index :users, :streak_updated_at
  end
end
