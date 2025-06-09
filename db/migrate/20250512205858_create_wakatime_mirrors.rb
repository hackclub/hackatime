class CreateWakatimeMirrors < ActiveRecord::Migration[8.0]
  def change
    create_table :wakatime_mirrors do |t|
      t.references :user, null: false, foreign_key: true
      t.string :endpoint_url, null: false, default: "https://wakatime.com/api/v1"
      t.string :encrypted_api_key, null: false
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :wakatime_mirrors, [ :user_id, :endpoint_url ], unique: true
  end
end
