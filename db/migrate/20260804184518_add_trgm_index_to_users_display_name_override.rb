class AddTrgmIndexToUsersDisplayNameOverride < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    enable_extension :pg_trgm unless extension_enabled?(:pg_trgm)

    add_index :users, :display_name_override,
              name: :index_users_on_display_name_override_trgm,
              using: :gin,
              opclass: :gin_trgm_ops,
              algorithm: :concurrently,
              if_not_exists: true
  end

  def down
    remove_index :users, :display_name_override,
                 name: :index_users_on_display_name_override_trgm,
                 algorithm: :concurrently,
                 if_exists: true
  end
end
