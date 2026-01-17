class AddSlackSyncedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :slack_synced_at, :datetime
  end
end
