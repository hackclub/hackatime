class AddYswsProgramToHeartbeats < ActiveRecord::Migration[8.1]
  def change
    add_column :heartbeats, :ysws_program, :integer, default: 0, null: false
  end
end
