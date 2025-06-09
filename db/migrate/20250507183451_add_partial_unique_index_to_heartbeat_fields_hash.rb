class AddPartialUniqueIndexToHeartbeatFieldsHash < ActiveRecord::Migration[8.0]
  def change
    # Add a partial index that only applies to non-deleted records
    add_index :heartbeats, :fields_hash,
              unique: true,
              where: "deleted_at IS NULL",
              name: "index_heartbeats_on_fields_hash_when_not_deleted"
  end
end
