class DropSailorsLogTables < ActiveRecord::Migration[8.1]
  def up
    drop_table :sailors_log_slack_notifications, if_exists: true
    drop_table :sailors_log_notification_preferences, if_exists: true
    drop_table :sailors_log_leaderboards, if_exists: true
    drop_table :sailors_logs, if_exists: true
  end

  def down
    create_table :sailors_logs do |t|
      t.jsonb :projects_summary, default: {}, null: false
      t.string :slack_uid, null: false
      t.timestamps
    end

    create_table :sailors_log_leaderboards do |t|
      t.string :slack_channel_id
      t.string :slack_uid
      t.text :message
      t.datetime :deleted_at
      t.timestamps
    end

    create_table :sailors_log_notification_preferences do |t|
      t.boolean :enabled, default: true, null: false
      t.string :slack_channel_id, null: false
      t.string :slack_uid, null: false
      t.timestamps
      t.index [ :slack_uid, :slack_channel_id ], unique: true, name: "idx_sailors_log_notification_preferences_unique_user_channel"
    end

    create_table :sailors_log_slack_notifications do |t|
      t.integer :project_duration, null: false
      t.string :project_name, null: false
      t.boolean :sent, default: false, null: false
      t.string :slack_channel_id, null: false
      t.string :slack_uid, null: false
      t.timestamps
    end
  end
end
