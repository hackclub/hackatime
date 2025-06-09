class AddAllowPublicStatsLookupToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :allow_public_stats_lookup, :boolean, default: true, null: false
  end
end
