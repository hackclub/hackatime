class RemoveStartDateUniqueIndexFromLeaderboards < ActiveRecord::Migration[8.1]
  def change
    remove_index :leaderboards, :start_date
  end
end
