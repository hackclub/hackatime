class CreateProjectLabels < ActiveRecord::Migration[8.0]
  def change
    create_table :project_labels do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :playable_url
      t.string :code_url
      t.string :hackatime_project, null: false

      t.timestamps
    end
  end
end
