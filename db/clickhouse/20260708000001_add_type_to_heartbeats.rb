class AddTypeToHeartbeats < ActiveRecord::Migration[8.1]
  def change
    add_column :heartbeats, :type, "String", low_cardinality: true, codec: "ZSTD(1)"
  end
end
