class CreateDesktopPairings < ActiveRecord::Migration[8.1]
  def change
    create_table :desktop_pairings do |t|
      t.references :user, null: false, foreign_key: true
      t.string :code_digest, null: false
      t.string :code_challenge, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.datetime :capture_consented_at, null: false
      t.timestamps
    end
    add_index :desktop_pairings, :code_digest, unique: true
  end
end
