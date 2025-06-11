class AddScopeToLeaderboards < ActiveRecord::Migration[8.0]
  def change
    add_column :leaderboards, :scope, :string
  end
end
