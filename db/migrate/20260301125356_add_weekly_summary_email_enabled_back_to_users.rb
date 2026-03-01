class AddWeeklySummaryEmailEnabledBackToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :weekly_summary_email_enabled, :boolean, default: false, null: false
  end
end
