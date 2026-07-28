class CreateHeartbeats < ActiveRecord::Migration[8.1]
  def change
    create_table :heartbeats do |t|
      t.belongs_to :user, null: false, foreign_key: true

      t.string :branch
      t.string :category
      t.string :dependencies, array: true, default: []
      t.string :editor
      t.string :entity
      t.string :language
      t.string :machine
      t.string :operating_system
      t.string :project
      t.string :type
      t.string :user_agent

      t.integer :line_additions
      t.integer :line_deletions
      t.integer :lineno
      t.integer :lines
      t.integer :cursorpos
      t.integer :project_root_count

      t.float :time, null: false

      t.boolean :is_write

      t.timestamps
    end

    add_index :heartbeats, [
      :user_id,
      :branch,
      :category,
      :dependencies,
      :editor,
      :entity,
      :language,
      :machine,
      :operating_system,
      :project,
      :type,
      :user_agent,
      :line_additions,
      :line_deletions,
      :lineno,
      :lines,
      :cursorpos,
      :project_root_count,
      :time,
      :is_write
    ], unique: true
  end
end
