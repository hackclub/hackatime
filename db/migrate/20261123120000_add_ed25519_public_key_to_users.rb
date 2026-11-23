class AddEd25519PublicKeyToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :ed25519_public_key, :binary
  end
end
