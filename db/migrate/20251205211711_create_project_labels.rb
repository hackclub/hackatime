class CreateProjectLabels < ActiveRecord::Migration[8.1]
  def change
    create_table :project_labels do |t|
      t.string :user_id
      t.string :project_key
      t.string :label

      t.timestamps
    end
    add_index :project_labels, :user_id
    add_index :project_labels, [ :user_id, :project_key ], unique: true
  end
end
