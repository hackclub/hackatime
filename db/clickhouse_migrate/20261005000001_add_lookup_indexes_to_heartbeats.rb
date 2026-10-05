# Admin lookups by IP address or machine and jobs that filter on created_at
# would otherwise scan the whole table, because ORDER BY starts with user_id.
class AddLookupIndexesToHeartbeats < ActiveRecord::Migration[8.1]
  INDEXES = {
    ip_address_bloom: "ip_address TYPE bloom_filter(0.01)",
    machine_bloom: "machine TYPE bloom_filter(0.01)",
    created_at_minmax: "created_at TYPE minmax"
  }.freeze

  def up
    INDEXES.each do |name, definition|
      execute "ALTER TABLE heartbeats ADD INDEX IF NOT EXISTS #{name} #{definition} GRANULARITY 1"
      execute "ALTER TABLE heartbeats MATERIALIZE INDEX #{name} SETTINGS mutations_sync = 1"
    end
  end

  def down
    INDEXES.each_key { |name| execute "ALTER TABLE heartbeats DROP INDEX IF EXISTS #{name}" }
  end
end
