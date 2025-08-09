class CreateProjectLabels < ActiveRecord::Migration[8.0]
  # where was ts before?
  # precedent for future to make migration infallible
  def change
    create_table :project_labels, if_not_exists: true do |t|
      t.string :user_id, null: false
      t.string :project_key, null: false
      t.string :label, null: false
      t.timestamps
    end

    add_index :project_labels, [ :user_id, :project_key ], unique: true, if_not_exists: true
    add_index :project_labels, :user_id, if_not_exists: true
  end
end
