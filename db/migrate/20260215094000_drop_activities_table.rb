class DropActivitiesTable < ActiveRecord::Migration[8.1]
  def up
    drop_table :activities, if_exists: true
  end

  def down
    create_table :activities do |t|
      t.belongs_to :trackable, polymorphic: true
      t.belongs_to :owner, polymorphic: true
      t.string :key
      t.text :parameters
      t.belongs_to :recipient, polymorphic: true

      t.timestamps
    end

    add_index :activities, %i[trackable_id trackable_type]
    add_index :activities, %i[owner_id owner_type]
    add_index :activities, %i[recipient_id recipient_type]
  end
end
