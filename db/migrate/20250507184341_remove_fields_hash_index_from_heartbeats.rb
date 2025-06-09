class RemoveFieldsHashIndexFromHeartbeats < ActiveRecord::Migration[8.0]
  def change
    remove_index :heartbeats, name: "index_heartbeats_on_fields_hash"
  end
end
