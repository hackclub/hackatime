class CreateProjectLabels < ActiveRecord::Migration[8.0]
  # where was ts before?
  def change
    create_table :project_labels do |t|
      t.string :user_id, null: false
      t.string :project_key, null: false
      t.string :label, null: false
      t.timestamps
    end

  add_index :project_labels, [ :user_id, :project_key ], unique: true
  add_index :project_labels, :user_id
  end
end
