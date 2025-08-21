class AddAltIdentifyingIndexes < ActiveRecord::Migration[8.0]
  def change
    add_index :heartbeats, :ip_address
    add_index :heartbeats, :machine
  end
end
