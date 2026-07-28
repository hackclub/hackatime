class CreateSignInTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :sign_in_tokens do |t|
      t.string :token
      t.references :user, null: false, foreign_key: true
      t.integer :auth_type
      t.datetime :expires_at
      t.datetime :used_at

      t.timestamps
    end
    add_index :sign_in_tokens, :token
  end
end
