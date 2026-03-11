class CreateSailorsLogNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :sailors_log_notification_preferences do |t|
      t.string :slack_uid, null: false
      t.string :slack_channel_id, null: false
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end
  end
end
