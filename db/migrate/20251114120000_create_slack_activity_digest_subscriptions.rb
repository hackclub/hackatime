class CreateSlackActivityDigestSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :slack_activity_digest_subscriptions do |t|
      t.string :slack_channel_id, null: false
      t.string :slack_team_id
      t.string :timezone, null: false, default: "UTC"
      t.integer :delivery_hour, null: false, default: 17
      t.boolean :enabled, null: false, default: true
      t.datetime :last_delivered_at
      t.references :created_by_user, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :slack_activity_digest_subscriptions, :slack_channel_id, unique: true
    add_index :slack_activity_digest_subscriptions, :enabled
  end
end
