class MoveEmailsToEmailAddresses < ActiveRecord::Migration[8.1]
  def up
    execute <<-SQL
      INSERT INTO email_addresses (email, user_id, created_at, updated_at)
      SELECT email, id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM users
      WHERE email IS NOT NULL
    SQL

    remove_column :users, :email
  end

  def down
    add_column :users, :email, :string

    execute <<-SQL
      UPDATE users
      SET email = (
        SELECT email
        FROM email_addresses
        WHERE email_addresses.user_id = users.id
        LIMIT 1
      )
    SQL
  end
end
