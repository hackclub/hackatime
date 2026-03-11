class AddIndexCategoryTimeHeartbeats < ActiveRecord::Migration[8.1]
  def change
    add_index :heartbeats, [ :category, :time ], name: 'index_heartbeats_on_category_and_time'
  end
end
