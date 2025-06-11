class RemoveScopeFromLeaderboards < ActiveRecord::Migration[8.0]
  def change
    remove_column :leaderboards, :scope, :string
  end
end
