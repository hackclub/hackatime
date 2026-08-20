class CreateGoalCompletionNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :goal_completion_notifications do |t|
      t.references :goal, null: false, foreign_key: true
      t.string :period, null: false
      t.datetime :period_started_at, null: false
      t.integer :target_seconds, null: false
      t.integer :tracked_seconds, null: false
      t.string :languages, array: true, default: [], null: false
      t.string :projects, array: true, default: [], null: false
      t.datetime :email_delivered_at
      t.datetime :slack_delivered_at

      t.timestamps
    end

    add_index :goal_completion_notifications,
      [ :goal_id, :period, :period_started_at ],
      unique: true,
      name: "index_goal_completion_notifications_on_goal_period"
  end
end
