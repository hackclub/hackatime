class AddIndexHeartbeatsOnUserAgent < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :heartbeats, :user_agent, algorithm: :concurrently
  end
end
