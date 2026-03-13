class CreateSailorsLogLeaderboards < ActiveRecord::Migration[8.1]
  def change
    create_table :sailors_log_leaderboards do |t|
      t.string :slack_channel_id
      t.string :slack_uid
      t.text :message

      t.timestamps
    end
  end
end
