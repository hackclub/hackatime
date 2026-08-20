class HashAdminApiKeys < ActiveRecord::Migration[8.1]
  def up
    add_column :admin_api_keys, :token_preview, :string

    admin_api_keys = Class.new(ActiveRecord::Base) do
      self.table_name = "admin_api_keys"
    end
    admin_api_keys.reset_column_information
    index_key = BlindIndex.index_key(table: "admin_api_keys", bidx_attribute: "token_bidx", encode: false)
    admin_api_keys.find_each do |key|
      raw_token = key[:token]
      key.update_columns(
        token: BlindIndex.generate_bidx(raw_token, key: index_key, algorithm: :pbkdf2_sha256, cost: { iterations: 1 }),
        # Deliberately not AdminApiKey::TOKEN_PREVIEW_LENGTH: the model can
        # change after this migration ships, but rows converted here must not.
        token_preview: raw_token.first(13)
      )
    end

    change_column_null :admin_api_keys, :token_preview, false
    rename_column :admin_api_keys, :token, :token_bidx
    if index_name_exists?(:admin_api_keys, :index_admin_api_keys_on_token)
      rename_index :admin_api_keys, :index_admin_api_keys_on_token, :index_admin_api_keys_on_token_bidx
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Raw admin API keys cannot be recovered from their blind indexes"
  end
end
