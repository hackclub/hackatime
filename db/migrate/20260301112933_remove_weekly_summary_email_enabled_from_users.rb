class RemoveWeeklySummaryEmailEnabledFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :weekly_summary_email_enabled, :boolean, default: true, null: false
  end
end
