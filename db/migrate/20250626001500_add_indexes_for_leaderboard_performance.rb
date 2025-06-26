class AddIndexesForLeaderboardPerformance < ActiveRecord::Migration[8.0]
  def change
    add_index :heartbeats, [ :user_id, :time, :category ], name: 'index_heartbeats_on_user_time_category'
    add_index :users, [ :timezone, :trust_level ], name: 'index_users_on_timezone_trust_level'
    add_index :users, :github_uid, name: 'index_users_on_github_uid'
  end
end
