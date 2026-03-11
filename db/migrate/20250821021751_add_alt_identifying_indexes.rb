class AddAltIdentifyingIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :heartbeats, :ip_address
    add_index :heartbeats, :machine
  end
end
