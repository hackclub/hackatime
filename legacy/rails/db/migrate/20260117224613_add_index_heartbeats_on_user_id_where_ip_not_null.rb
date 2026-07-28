class AddIndexHeartbeatsOnUserIdWhereIpNotNull < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :heartbeats,
              [ :user_id, :id ],
              where: "ip_address IS NOT NULL AND deleted_at IS NULL",
              order: { id: :desc },
              name: "index_heartbeats_on_user_id_with_ip",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
