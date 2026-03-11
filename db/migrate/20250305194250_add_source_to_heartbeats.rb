class Heartbeat < ApplicationRecord
end

class AddSourceToHeartbeats < ActiveRecord::Migration[8.1]
  def change
    add_column :heartbeats, :source_type, :integer

    Heartbeat.update_all(source_type: 1)

    change_column_null :heartbeats, :source_type, false
    change_column_default :heartbeats, :source_type, to: 0
  end
end
