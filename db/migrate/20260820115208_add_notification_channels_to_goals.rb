class AddNotificationChannelsToGoals < ActiveRecord::Migration[8.1]
  def change
    add_column :goals, :notify_by_email, :boolean, default: false, null: false
    add_column :goals, :notify_by_slack, :boolean, default: false, null: false
  end
end
