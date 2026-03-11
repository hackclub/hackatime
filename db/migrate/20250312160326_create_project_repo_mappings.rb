class CreateProjectRepoMappings < ActiveRecord::Migration[8.1]
  def change
    create_table :project_repo_mappings do |t|
      t.references :user, null: false, foreign_key: true
      t.string :project_name, null: false
      t.string :repo_url, null: false

      t.timestamps
    end

    add_index :project_repo_mappings, [ :user_id, :project_name ], unique: true
  end
end
