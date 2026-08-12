class CreateHeartbeatIdAllocator < ActiveRecord::Migration[8.0]
  def up
    create_table :heartbeat_id_allocations
    create_table :heartbeat_clickhouse_versions

    id_sequence = connection.quote("#{connection.current_schema}.heartbeat_id_allocations_id_seq")
    version_sequence = connection.quote("#{connection.current_schema}.heartbeat_clickhouse_versions_id_seq")
    heartbeat_sequence = connection.quote("#{connection.current_schema}.heartbeats_id_seq")
    execute <<~SQL.squish
      SELECT setval(
        #{version_sequence},
        (EXTRACT(EPOCH FROM clock_timestamp()) * 1000000)::bigint
      )
    SQL
    execute <<~SQL.squish
      SELECT setval(
        #{id_sequence},
        GREATEST(
          (EXTRACT(EPOCH FROM clock_timestamp()) * 1000000)::bigint,
          COALESCE(pg_sequence_last_value(#{heartbeat_sequence}::regclass), 0)
        )
      )
    SQL

    change_column_default :heartbeats, :id,
      from: -> { "nextval('heartbeats_id_seq'::regclass)" },
      to: -> { "nextval('heartbeat_id_allocations_id_seq'::regclass)" }
    add_column :heartbeat_transfers, :copy_version, :bigint, null: false,
      default: -> { "nextval('heartbeat_clickhouse_versions_id_seq'::regclass)" }
    add_column :heartbeat_transfers, :delete_version, :bigint, null: false,
      default: -> { "nextval('heartbeat_clickhouse_versions_id_seq'::regclass)" }
    add_column :heartbeat_deletions, :clickhouse_version, :bigint, null: false,
      default: -> { "nextval('heartbeat_clickhouse_versions_id_seq'::regclass)" }
  end

  def down
    remove_column :heartbeat_deletions, :clickhouse_version
    remove_column :heartbeat_transfers, :delete_version
    remove_column :heartbeat_transfers, :copy_version
    change_column_default :heartbeats, :id,
      from: -> { "nextval('heartbeat_id_allocations_id_seq'::regclass)" },
      to: -> { "nextval('heartbeats_id_seq'::regclass)" }
    drop_table :heartbeat_clickhouse_versions
    drop_table :heartbeat_id_allocations
  end
end
