class AddScopesAndExpiryToAdminApiKeys < ActiveRecord::Migration[8.1]
  # Snapshot of AdminApiKey::SCOPES when scopes were introduced. Keys created
  # before then keep full access until they are revoked 48 days from now.
  LEGACY_SCOPES = %w[
    users:read users:write heartbeats:read bans:read bans:write
    leaderboard_shadowbans:read leaderboard_shadowbans:write
    deletion_requests:read deletion_requests:write
    permissions:read permissions:write admin_api_keys:read admin_api_keys:write
  ].freeze

  def up
    execute "SET LOCAL lock_timeout = '5s'"
    add_column :admin_api_keys, :scopes, :string, array: true, null: false, default: []
    add_column :admin_api_keys, :expires_at, :datetime
    add_column :admin_api_keys, :expiry_notice_sent_at, :datetime

    execute <<~SQL
      UPDATE admin_api_keys
      SET scopes = ARRAY[#{LEGACY_SCOPES.map { |scope| connection.quote(scope) }.join(", ")}]::varchar[],
          expires_at = CURRENT_TIMESTAMP + INTERVAL '48 days'
    SQL
  end

  def down
    remove_column :admin_api_keys, :expiry_notice_sent_at
    remove_column :admin_api_keys, :expires_at
    remove_column :admin_api_keys, :scopes
  end
end
