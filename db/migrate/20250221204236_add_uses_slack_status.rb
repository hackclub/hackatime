class AddUsesSlackStatus < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :uses_slack_status, :boolean, default: false, null: false
  end
end
