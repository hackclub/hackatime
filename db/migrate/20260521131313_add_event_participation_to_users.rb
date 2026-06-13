class AddEventParticipationToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :event_participation, :integer, default: 0, null: false
  end
end
