class AddEventParticipationBackfilledToUsers < ActiveRecord::Migration[8.1]
  def up
    # Existing users start false (need backfill), future inserts default true
    # (new users have no history to backfill)
    add_column :users, :event_participation_backfilled, :boolean, default: false, null: false
    change_column_default :users, :event_participation_backfilled, true
  end

  def down
    remove_column :users, :event_participation_backfilled
  end
end
