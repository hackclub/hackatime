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
        execute <<~SQL
          CREATE INDEX CONCURRENTLY IF NOT EXISTS index_#{table}_on_#{column}_trgm
            ON #{table}
            USING gin (#{column} gin_trgm_ops)
        SQL
      end
    end
  end

  def down
    INDEXES.each do |table, columns|
      columns.each do |column|
        execute "DROP INDEX CONCURRENTLY IF EXISTS index_#{table}_on_#{column}_trgm"
      end
    end
  end
end
