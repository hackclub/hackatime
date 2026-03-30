class AddGenerationDurationSecondsToLeaderboards < ActiveRecord::Migration[8.1]
  def change
    add_column :leaderboards, :generation_duration_seconds, :integer
  end
end
