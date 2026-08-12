class AddClickhouseVersionToHeartbeatJa4Nullifications < ActiveRecord::Migration[8.1]
  def change
    add_column :heartbeat_ja4_nullifications, :clickhouse_version, :bigint, null: false,
      default: -> { "nextval('heartbeat_clickhouse_versions_id_seq'::regclass)" }
  end
end
