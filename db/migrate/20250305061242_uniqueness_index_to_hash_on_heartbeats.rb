
class UniquenessIndexToHashOnHeartbeats < ActiveRecord::Migration[8.1]
  def change
    attributes = [
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
    ]

    # clean up the index from ./20250303180842_create_heartbeats.rb
    remove_index :heartbeats,
                 attributes,
                 unique: true

    add_column :heartbeats, :fields_hash, :text
  end
end
