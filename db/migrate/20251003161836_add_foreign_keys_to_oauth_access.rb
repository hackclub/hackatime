class AddForeignKeysToOauthAccess < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :oauth_access_grants, :users, column: :resource_owner_id
    add_foreign_key :oauth_access_tokens, :users, column: :resource_owner_id
  end
end
