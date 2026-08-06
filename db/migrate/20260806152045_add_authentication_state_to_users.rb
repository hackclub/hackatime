class AddAuthenticationStateToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  BATCH_SIZE = 1_000

  def up
    add_column :users, :anonymized_at, :datetime
    # Starting at one intentionally invalidates browser sessions created by the
    # pre-HCA release, which did not store an authentication version.
    add_column :users, :authentication_version, :integer, default: 1, null: false

    backfill_completed_deletions
    clear_hca_credentials
  end

  def down
    remove_column :users, :authentication_version
    remove_column :users, :anonymized_at
  end

  private

  def backfill_completed_deletions
    loop do
      updated = connection.update(<<~SQL.squish)
        WITH completed_deletions AS (
          SELECT users.id, MAX(COALESCE(deletion_requests.completed_at, deletion_requests.updated_at, deletion_requests.created_at)) AS completed_at
          FROM users
          INNER JOIN deletion_requests ON deletion_requests.user_id = users.id
          WHERE deletion_requests.status = 3
            AND users.anonymized_at IS NULL
          GROUP BY users.id
          ORDER BY users.id
          LIMIT #{BATCH_SIZE}
        )
        UPDATE users
        SET anonymized_at = completed_deletions.completed_at
        FROM completed_deletions
        WHERE users.id = completed_deletions.id
      SQL
      break if updated.zero?
    end
  end

  def clear_hca_credentials
    loop do
      updated = connection.update(<<~SQL.squish)
        UPDATE users
        SET hca_access_token = NULL,
            hca_scopes = '{}'
        WHERE id IN (
          SELECT id
          FROM users
          WHERE hca_access_token IS NOT NULL OR CARDINALITY(hca_scopes) > 0
          ORDER BY id
          LIMIT #{BATCH_SIZE}
        )
      SQL
      break if updated.zero?
    end
  end
end
