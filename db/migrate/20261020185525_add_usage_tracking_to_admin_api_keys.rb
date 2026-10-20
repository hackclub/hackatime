class AddUsageTrackingToAdminApiKeys < ActiveRecord::Migration[8.1]
  def change
    reversible do |direction|
      direction.up { execute "SET LOCAL lock_timeout = '5s'" }
    end
    add_column :admin_api_keys, :last_used_at, :datetime
    add_column :admin_api_keys, :usage_tracking_enqueued_at, :datetime
  end
end
