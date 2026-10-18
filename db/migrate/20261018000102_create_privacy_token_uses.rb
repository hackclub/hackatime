class CreatePrivacyTokenUses < ActiveRecord::Migration[8.1]
  def change
    create_table :privacy_token_uses, id: false do |t|
      t.string :jti, primary_key: true
      t.datetime :used_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end
    add_index :privacy_token_uses, :used_at
  end
end
