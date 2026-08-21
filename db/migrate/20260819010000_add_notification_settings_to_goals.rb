class AddNotificationSettingsToGoals < ActiveRecord::Migration[8.1]
  def change
    add_column :goals, :notify_slack, :boolean, default: false, null: false
    add_column :goals, :notify_email, :boolean, default: false, null: false
    add_column :goals, :last_missed_notification_period_start, :datetime
  end
end
