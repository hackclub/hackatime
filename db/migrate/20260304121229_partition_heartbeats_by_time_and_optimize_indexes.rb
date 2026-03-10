class PartitionHeartbeatsByTimeAndOptimizeIndexes < ActiveRecord::Migration[8.1]
  def up
    say "Creating partitioned heartbeats table..."

    # Step 1: Create the new partitioned table (drops unused _id FK columns)
    execute <<~SQL
      CREATE TABLE heartbeats_partitioned (
        id bigint NOT NULL DEFAULT nextval('heartbeats_id_seq'),
        branch character varying,
        category character varying,
        created_at timestamp(6) without time zone NOT NULL,
        cursorpos integer,
        deleted_at timestamp(6) without time zone,
        dependencies character varying[] DEFAULT '{}',
        editor character varying,
        entity character varying,
        fields_hash text,
        ip_address inet,
        is_write boolean,
        language character varying,
        line_additions integer,
        line_deletions integer,
        lineno integer,
        lines integer,
        machine character varying,
        operating_system character varying,
        project character varying,
        project_root_count integer,
        raw_heartbeat_upload_id bigint,
        source_type integer NOT NULL,
        "time" double precision NOT NULL,
        type character varying,
        updated_at timestamp(6) without time zone NOT NULL,
        user_agent character varying,
        user_id bigint NOT NULL,
        ysws_program integer DEFAULT 0 NOT NULL
      ) PARTITION BY RANGE ("time")
    SQL

    # Step 2: Create monthly partitions from 2024-01 through 2026-06
    partitions = []

    # Pre-2024 catch-all
    partitions << { name: "heartbeats_before_2024", from: "MINVALUE", to: Time.utc(2024, 1, 1).to_i.to_s }

    # Monthly partitions: 2024-01 through 2026-06
    (2024..2026).each do |year|
      end_month = (year == 2026) ? 6 : 12
      (1..end_month).each do |month|
        next_year = month == 12 ? year + 1 : year
        next_month = month == 12 ? 1 : month + 1
        from_ts = Time.utc(year, month, 1).to_i
        to_ts = Time.utc(next_year, next_month, 1).to_i
        partitions << { name: "heartbeats_#{year}_#{'%02d' % month}", from: from_ts.to_s, to: to_ts.to_s }
      end
    end

    # Default partition for anything beyond 2026-06
    partitions << { name: "heartbeats_default", from: Time.utc(2026, 7, 1).to_i.to_s, to: "MAXVALUE" }

    partitions.each do |p|
      say "  Creating partition #{p[:name]}..."
      execute "CREATE TABLE #{p[:name]} PARTITION OF heartbeats_partitioned FOR VALUES FROM (#{p[:from]}) TO (#{p[:to]})"
    end

    # Step 3: Create the optimized index set (on parent, propagates to partitions)
    say "Creating optimized indexes..."

    # Core: user + time (covers dashboard range queries, export, most-recent, counts)
    execute <<~SQL
      CREATE INDEX idx_heartbeats_part_user_time
      ON heartbeats_partitioned (user_id, "time")
      WHERE deleted_at IS NULL
    SQL

    # Dashboard filter: user + project + time
    execute <<~SQL
      CREATE INDEX idx_heartbeats_part_user_project_time
      ON heartbeats_partitioned (user_id, project, "time")
      WHERE deleted_at IS NULL AND project IS NOT NULL
    SQL

    # Dashboard filter: user + language + time
    execute <<~SQL
      CREATE INDEX idx_heartbeats_part_user_language_time
      ON heartbeats_partitioned (user_id, language, "time")
      WHERE deleted_at IS NULL AND language IS NOT NULL
    SQL

    # Dashboard filter: user + editor + time
    execute <<~SQL
      CREATE INDEX idx_heartbeats_part_user_editor_time
      ON heartbeats_partitioned (user_id, editor, "time")
      WHERE deleted_at IS NULL AND editor IS NOT NULL
    SQL

    # Dashboard filter: user + operating_system + time
    execute <<~SQL
      CREATE INDEX idx_heartbeats_part_user_os_time
      ON heartbeats_partitioned (user_id, operating_system, "time")
      WHERE deleted_at IS NULL AND operating_system IS NOT NULL
    SQL

    # Dashboard filter: user + category + time
    execute <<~SQL
      CREATE INDEX idx_heartbeats_part_user_category_time
      ON heartbeats_partitioned (user_id, category, "time")
      WHERE deleted_at IS NULL AND category IS NOT NULL
    SQL

    # Dedup unique constraint: fields_hash + time (time required for partitioned unique indexes)
    execute <<~SQL
      CREATE UNIQUE INDEX idx_heartbeats_part_fields_hash_uniq
      ON heartbeats_partitioned (fields_hash, "time")
      WHERE deleted_at IS NULL
    SQL

    # Wakatime mirror sync: user + id for direct entries
    execute <<~SQL
      CREATE INDEX idx_heartbeats_part_user_id_direct
      ON heartbeats_partitioned (user_id, id)
      WHERE deleted_at IS NULL AND source_type = 0
    SQL

    # Currently hacking job: recent time scan without user_id
    execute <<~SQL
      CREATE INDEX idx_heartbeats_part_current_hacking
      ON heartbeats_partitioned ("time" DESC)
      WHERE deleted_at IS NULL AND source_type = 0 AND category = 'coding'
    SQL

    # Admin IP lookup
    execute <<~SQL
      CREATE INDEX idx_heartbeats_part_ip
      ON heartbeats_partitioned (ip_address)
      WHERE deleted_at IS NULL AND ip_address IS NOT NULL
    SQL

    # Admin machine lookup
    execute <<~SQL
      CREATE INDEX idx_heartbeats_part_machine
      ON heartbeats_partitioned (machine)
      WHERE deleted_at IS NULL AND machine IS NOT NULL
    SQL

    # Country code geocoding: user + id DESC with IP present
    execute <<~SQL
      CREATE INDEX idx_heartbeats_part_user_ip_id
      ON heartbeats_partitioned (user_id, id DESC)
      WHERE deleted_at IS NULL AND ip_address IS NOT NULL
    SQL

    # Step 4: Rename old table, then copy data
    say "Renaming old table..."
    execute 'ALTER TABLE heartbeats RENAME TO heartbeats_old_unpartitioned'

    say "Copying data (this may take a while)..."
    execute <<~SQL
      INSERT INTO heartbeats_partitioned (
        id, branch, category, created_at, cursorpos, deleted_at, dependencies,
        editor, entity, fields_hash, ip_address, is_write, language,
        line_additions, line_deletions, lineno, lines, machine,
        operating_system, project, project_root_count, raw_heartbeat_upload_id,
        source_type, "time", type, updated_at, user_agent, user_id, ysws_program
      )
      SELECT
        id, branch, category, created_at, cursorpos, deleted_at, dependencies,
        editor, entity, fields_hash, ip_address, is_write, language,
        line_additions, line_deletions, lineno, lines, machine,
        operating_system, project, project_root_count, raw_heartbeat_upload_id,
        source_type, "time", type, updated_at, user_agent, user_id, ysws_program
      FROM heartbeats_old_unpartitioned
      ORDER BY "time"
    SQL

    # Step 5: Swap in the new table
    say "Swapping in partitioned table..."
    execute 'ALTER TABLE heartbeats_partitioned RENAME TO heartbeats'
    execute "ALTER SEQUENCE heartbeats_id_seq OWNED BY heartbeats.id"

    say "Done! Old table preserved as heartbeats_old_unpartitioned."
    say "Run 'DROP TABLE heartbeats_old_unpartitioned CASCADE' after verifying everything works."
  end

  def down
    execute 'ALTER TABLE heartbeats RENAME TO heartbeats_partitioned'

    if table_exists?(:heartbeats_old_unpartitioned)
      execute 'ALTER TABLE heartbeats_old_unpartitioned RENAME TO heartbeats'
      execute "ALTER SEQUENCE heartbeats_id_seq OWNED BY heartbeats.id"
      execute 'DROP TABLE heartbeats_partitioned CASCADE'
    else
      raise ActiveRecord::IrreversibleMigration,
        "Cannot reverse: heartbeats_old_unpartitioned has been dropped. Restore from backup."
    end
  end
end
