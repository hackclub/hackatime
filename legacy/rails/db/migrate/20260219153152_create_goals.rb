class CreateGoals < ActiveRecord::Migration[8.1]
  def change
    create_table :goals do |t|
      t.references :user, null: false, foreign_key: true
      t.string :period, null: false
      t.integer :target_seconds, null: false
      t.string :languages, array: true, default: [], null: false
      t.string :projects, array: true, default: [], null: false
      t.timestamps
    end

    add_index :goals,
      [ :user_id, :period, :target_seconds, :languages, :projects ],
      name: "index_goals_on_user_and_scope"
  end
end
