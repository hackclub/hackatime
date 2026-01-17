class AddSlackSyncedAtToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :users, :slack_synced_at, :datetime
  end
end
