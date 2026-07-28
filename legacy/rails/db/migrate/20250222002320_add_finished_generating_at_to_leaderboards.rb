class AddFinishedGeneratingAtToLeaderboards < ActiveRecord::Migration[8.1]
  def change
    add_column :leaderboards, :finished_generating_at, :datetime
  end
end
