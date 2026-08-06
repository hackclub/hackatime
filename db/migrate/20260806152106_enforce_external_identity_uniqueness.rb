class EnforceExternalIdentityUniqueness < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  BATCH_SIZE = 1_000

  def up
    ensure_identity_data_is_unique!

    # A failed concurrent build leaves an invalid index behind. Removing any
    # retry debris makes this non-transactional migration safe to rerun.
    remove_index :users, name: :index_users_on_hca_id_unique, algorithm: :concurrently, if_exists: true
    remove_index :email_addresses, name: :index_email_addresses_on_lower_email, algorithm: :concurrently, if_exists: true

    normalize_emails

    add_index :users,
      :hca_id,
      unique: true,
      where: "hca_id IS NOT NULL",
      name: :index_users_on_hca_id_unique,
      algorithm: :concurrently
    add_index :email_addresses,
      "LOWER(email)",
      unique: true,
      name: :index_email_addresses_on_lower_email,
      algorithm: :concurrently

    remove_index :users,
      name: :index_users_on_hca_id,
      algorithm: :concurrently,
      if_exists: true
  end

  def down
    add_index :users,
      :hca_id,
      name: :index_users_on_hca_id,
      algorithm: :concurrently,
      if_not_exists: true

    remove_index :email_addresses,
      name: :index_email_addresses_on_lower_email,
      algorithm: :concurrently,
      if_exists: true
    remove_index :users,
      name: :index_users_on_hca_id_unique,
      algorithm: :concurrently,
      if_exists: true
  end

  private

  def normalize_emails
    loop do
      updated = connection.update(<<~SQL.squish)
        UPDATE email_addresses
        SET email = LOWER(email)
        WHERE id IN (
          SELECT id
          FROM email_addresses
          WHERE email <> LOWER(email)
          ORDER BY id
          LIMIT #{BATCH_SIZE}
        )
      SQL
      break if updated.zero?
    end
  end

  def ensure_identity_data_is_unique!
    duplicate_email_groups = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*)
      FROM (
        SELECT LOWER(email)
        FROM email_addresses
        GROUP BY LOWER(email)
        HAVING COUNT(*) > 1
      ) duplicates
    SQL
    duplicate_hca_groups = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*)
      FROM (
        SELECT hca_id
        FROM users
        WHERE hca_id IS NOT NULL
        GROUP BY hca_id
        HAVING COUNT(*) > 1
      ) duplicates
    SQL
    return if duplicate_email_groups.zero? && duplicate_hca_groups.zero?

    raise ActiveRecord::MigrationError,
      "External identities are not unique: #{duplicate_email_groups} case-insensitive email groups and #{duplicate_hca_groups} HCA ID groups require manual resolution"
  end
end
