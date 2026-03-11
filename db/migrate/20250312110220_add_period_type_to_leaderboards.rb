class AddPeriodTypeToLeaderboards < ActiveRecord::Migration[8.1]
  def change
    add_column :leaderboards, :period_type, :integer, default: 0, null: false
  end
end
