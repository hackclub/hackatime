class SeedMailkickSubscriptionsFromColumn < ActiveRecord::Migration[8.1]
  def up
    return unless column_exists?(:users, :weekly_summary_email_enabled)

    execute <<~SQL
      INSERT INTO mailkick_subscriptions (subscriber_type, subscriber_id, list, created_at, updated_at)
      SELECT 'User', id, 'weekly_summary', NOW(), NOW()
      FROM users
      WHERE weekly_summary_email_enabled = TRUE
      ON CONFLICT (subscriber_type, subscriber_id, list) DO NOTHING
    SQL
  end

  def down
    # No-op: we don't undo seeding
  end
end
