class AddTrustLevelToUsers < ActiveRecord::Migration[7.1]
  def up
    add_column :users, :trust_level, :integer, default: 0, null: false

    # Convert existing omit_from_leaderboard values
    execute <<-SQL
      UPDATE users#{' '}
      SET trust_level = CASE#{' '}
        WHEN omit_from_leaderboard = true THEN 1  -- untrusted
        ELSE 0  -- default
      END
    SQL

    # Remove the old column
    remove_column :users, :omit_from_leaderboard
  end

  def down
    add_column :users, :omit_from_leaderboard, :boolean, default: false, null: false

    # Convert back
    execute <<-SQL
      UPDATE users#{' '}
      SET omit_from_leaderboard = CASE#{' '}
        WHEN trust_level = 1 THEN true  -- untrusted
        ELSE false  -- default
      END
    SQL

    remove_column :users, :trust_level
  end
end
