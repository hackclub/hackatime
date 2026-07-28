class AddTrgmIndexesForAdminUserSearch < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # GIN trigram indexes let the admin user-search ILIKE '%term%' predicates run
  # against an index instead of seq-scanning users / email_addresses.
  INDEXES = {
    users: %i[username slack_username github_username],
    email_addresses: %i[email]
  }.freeze

  def up
    enable_extension :pg_trgm unless extension_enabled?(:pg_trgm)

    INDEXES.each do |table, columns|
      columns.each do |column|
        add_index table, column,
                  name: "index_#{table}_on_#{column}_trgm",
                  using: :gin,
                  opclass: :gin_trgm_ops,
                  algorithm: :concurrently,
                  if_not_exists: true
      end
    end
  end

  def down
    INDEXES.each do |table, columns|
      columns.each do |column|
        remove_index table, column,
                     name: "index_#{table}_on_#{column}_trgm",
                     algorithm: :concurrently,
                     if_exists: true
      end
    end
  end
end
