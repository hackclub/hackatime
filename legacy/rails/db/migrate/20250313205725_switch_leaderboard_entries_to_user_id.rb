class SwitchLeaderboardEntriesToUserId < ActiveRecord::Migration[8.1]
  def up
    # Add user_id column
    add_column :leaderboard_entries, :user_id, :bigint

    # Add foreign key constraint
    add_foreign_key :leaderboard_entries, :users

    # Migrate existing data
    execute <<-SQL
      UPDATE leaderboard_entries le
      SET user_id = u.id
      FROM users u
      WHERE le.slack_uid = u.slack_uid
    SQL

    # Add null constraint after data is migrated
    change_column_null :leaderboard_entries, :user_id, false

    # Update unique index to use user_id instead of slack_uid
    remove_index :leaderboard_entries, name: "idx_leaderboard_entries_on_leaderboard_and_user"
    add_index :leaderboard_entries, [ :leaderboard_id, :user_id ], unique: true, name: "idx_leaderboard_entries_on_leaderboard_and_user"

    # Remove slack_uid column
    remove_column :leaderboard_entries, :slack_uid
  end

  def down
    # Add back slack_uid column
    add_column :leaderboard_entries, :slack_uid, :string

    # Migrate data back
    execute <<-SQL
      UPDATE leaderboard_entries le
      SET slack_uid = u.slack_uid
      FROM users u
      WHERE le.user_id = u.id
    SQL

    # Remove user_id column and its foreign key
    remove_foreign_key :leaderboard_entries, :users
    remove_column :leaderboard_entries, :user_id

    # Restore original index
    remove_index :leaderboard_entries, name: "idx_leaderboard_entries_on_leaderboard_and_user"
    add_index :leaderboard_entries, [ :leaderboard_id, :slack_uid ], unique: true, name: "idx_leaderboard_entries_on_leaderboard_and_user"
  end
end
