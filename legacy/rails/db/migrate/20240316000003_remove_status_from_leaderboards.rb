class RemoveStatusFromLeaderboards < ActiveRecord::Migration[8.1]
  def change
    remove_column :leaderboards, :status, :integer
  end
end
