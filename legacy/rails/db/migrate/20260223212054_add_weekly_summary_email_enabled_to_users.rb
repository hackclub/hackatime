class AddWeeklySummaryEmailEnabledToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :weekly_summary_email_enabled, :boolean, default: true, null: false
  end
end
