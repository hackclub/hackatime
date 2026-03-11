class CreateSailorsLogSlackNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :sailors_log_slack_notifications do |t|
      t.string :slack_uid, null: false
      t.string :slack_channel_id, null: false
      t.string :project_name, null: false
      t.integer :project_duration, null: false

      t.boolean :sent, null: false, default: false

      t.timestamps
    end
  end
end
