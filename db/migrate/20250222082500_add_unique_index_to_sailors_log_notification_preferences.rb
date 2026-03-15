class AddUniqueIndexToSailorsLogNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    add_index :sailors_log_notification_preferences,
              [ :slack_uid, :slack_channel_id ],
              unique: true,
              name: 'idx_sailors_log_notification_preferences_unique_user_channel'
  end
end
