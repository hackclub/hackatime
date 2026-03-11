class CreateSailorsLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :sailors_logs do |t|
      t.string :slack_uid, null: false
      t.jsonb :projects_summary, null: false, default: {}

      t.timestamps
    end
  end
end
