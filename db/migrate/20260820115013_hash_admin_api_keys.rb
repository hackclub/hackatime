class HashAdminApiKeys < ActiveRecord::Migration[8.1]
  def up
    add_column :admin_api_keys, :token_preview, :string

    admin_api_keys = Class.new(ActiveRecord::Base) do
      self.table_name = "admin_api_keys"
    end
    admin_api_keys.reset_column_information
    admin_api_keys.find_each do |key|
      raw_token = key[:token]
      key.update_columns(
        token: Digest::SHA256.hexdigest(raw_token),
        token_preview: raw_token.first(21)
      )
    end

    change_column_null :admin_api_keys, :token_preview, false
    rename_column :admin_api_keys, :token, :token_digest
    if index_name_exists?(:admin_api_keys, :index_admin_api_keys_on_token)
      rename_index :admin_api_keys, :index_admin_api_keys_on_token, :index_admin_api_keys_on_token_digest
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Raw admin API keys cannot be recovered from their digests"
  end
end
