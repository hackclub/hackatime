namespace :clickhouse do
  desc "Apply ClickHouse schema files"
  task migrate: :environment do
    client = ClickHouse::Client.current
    server_version = client.select("SELECT version() AS version").first.fetch("version")
    abort "ClickHouse 26.7.3.19 is required, found #{server_version}" unless server_version == "26.7.3.19"

    schema_statements = lambda do |path|
      File.read(path).split(/;\s*(?:\n|\z)/).reject(&:blank?)
    end

    client.execute(<<~SQL)
      CREATE TABLE IF NOT EXISTS schema_migrations
      (
          version String,
          applied_at DateTime64(6, 'UTC') DEFAULT now64(6)
      )
      ENGINE = ReplacingMergeTree
      ORDER BY version
    SQL

    schema_files = {
      "heartbeats" => [ "001_create_heartbeats.sql", "heartbeats" ],
      "heartbeats_by_time" => [ "009_create_heartbeats_by_time.sql", "heartbeats_by_time" ],
      "heartbeat_store" => [ "012_create_heartbeat_store.sql", "heartbeat_store" ],
      "heartbeat_aliases" => [ "013_create_heartbeat_aliases.sql", "heartbeat_aliases" ]
    }
    object_exists = lambda do |name|
      client.select(<<~SQL.squish).first.fetch("object_count").to_i.positive?
        SELECT count() AS object_count FROM system.tables
        WHERE database = currentDatabase() AND name = '#{name}'
      SQL
    end
    validate_schema = lambda do |name|
      file, canonical_name = schema_files.fetch(name)
      reference_name = "_hackatime_schema_reference_#{name}"
      ddl = schema_statements.call(Rails.root.join("db/clickhouse", file)).sole
        .sub(/(CREATE (?:MATERIALIZED VIEW|TABLE))(?: IF NOT EXISTS)? #{canonical_name}/, "\\1 #{reference_name}")
      client.execute("DROP TABLE IF EXISTS #{reference_name}")
      begin
        client.execute(ddl)
        normalize = ->(statement) { statement.sub(/\A(CREATE (?:MATERIALIZED VIEW|TABLE)) [^\s(]+/, "\\1 __object__") }
        actual = normalize.call(client.select("SHOW CREATE TABLE #{name}").first.fetch("statement"))
        expected = normalize.call(client.select("SHOW CREATE TABLE #{reference_name}").first.fetch("statement"))
        abort "ClickHouse object #{name} does not exactly match #{file}" unless actual == expected
      ensure
        client.execute("DROP TABLE IF EXISTS #{reference_name}")
      end
    end

    applied = client.select("SELECT DISTINCT version FROM schema_migrations").pluck("version").to_set
    migration_paths = Dir[Rails.root.join("db/clickhouse/*.sql")].sort
    expected_versions = migration_paths.map { |path| File.basename(path, ".sql") }.to_set
    unknown_versions = applied - expected_versions
    if unknown_versions.any?
      abort "Unknown ClickHouse migrations: #{unknown_versions.to_a.sort.join(', ')}. " \
        "Do not delete production history; reset only an explicitly disposable pre-cutover database."
    end
    migration_paths.each do |path|
      migration_version = File.basename(path, ".sql")
      next if applied.include?(migration_version)

      schema_statements.call(path).each { |statement| client.execute(statement) }
      schema_files.each_key do |name|
        validate_schema.call(name) if object_exists.call(name)
      end
      client.insert_json_each_row("schema_migrations", [ { version: migration_version } ])
      puts "Applied ClickHouse migration #{migration_version}"
    end

    schema_files.each_key { |name| validate_schema.call(name) }
    recorded_versions = client.select("SELECT DISTINCT version FROM schema_migrations").pluck("version").to_set
    abort "ClickHouse migration history differs from db/clickhouse" unless recorded_versions == expected_versions
  end

  desc "Backfill PostgreSQL heartbeats into ClickHouse"
  task backfill: :environment do
    abort "Run backfill with HEARTBEAT_STORE=postgresql" if HeartbeatRepository.clickhouse?
    abort "Set HEARTBEAT_MUTATIONS_STOPPED=1 on every web and worker process" unless
      ENV["HEARTBEAT_MUTATIONS_STOPPED"] == "1"
    unfinished = HeartbeatTransfer.where.not(status: :completed).count +
      HeartbeatDeletion.where.not(status: :completed).count +
      HeartbeatJa4Nullification.where(completed_at: nil).count
    abort "Complete all heartbeat lifecycle controls before backfill (#{unfinished} unfinished)" if unfinished.positive?

    batch_size = ENV.fetch("BATCH_SIZE", 10_000).to_i
    current_max_id = Heartbeat.postgresql_unscoped.maximum(:id).to_i
    cutover = HeartbeatCutover.find_or_create_by!(id: 1) { |record| record.source_through_id = current_max_id }
    if ENV["HEARTBEAT_WRITES_STOPPED"] == "1" && cutover.source_through_id != current_max_id
      cutover.update!(source_through_id: current_max_id, verified_through_id: nil, verified_at: nil)
    end
    after_id = cutover.backfilled_through_id
    through_id = cutover.source_through_id
    invalid_hashes = Heartbeat.postgresql_unscoped
      .where("fields_hash IS NULL OR octet_length(fields_hash) <> 32").count
    abort "Backfill blocked: #{invalid_hashes} heartbeats have an invalid fields_hash" if invalid_hashes.positive?
    invalid_unsigned = Heartbeat.postgresql_unscoped.where(
      "id < 0 OR user_id < 0 OR source_type NOT BETWEEN 0 AND 255 OR ysws_program NOT BETWEEN 0 AND 255 OR ja4_id < 0"
    ).count
    abort "Backfill blocked: #{invalid_unsigned} heartbeats exceed unsigned ClickHouse types" if invalid_unsigned.positive?
    non_finite_times = Heartbeat.postgresql_unscoped.where("time::text IN ('NaN', 'Infinity', '-Infinity')").count
    abort "Backfill blocked: #{non_finite_times} heartbeats have non-finite timestamps" if non_finite_times.positive?

    migrated = 0
    puts "Backfilling heartbeat IDs #{after_id + 1} through #{through_id}"
    Heartbeat.postgresql_unscoped.where(id: (after_id + 1)..through_id).order(:id).find_in_batches(batch_size:) do |batch|
      HeartbeatRepository.current.backfill(batch)
      after_id = batch.last.id
      cutover.update!(backfilled_through_id: after_id)
      migrated += batch.length
      puts "Backfilled through heartbeat ID #{after_id} (#{migrated} rows this run)"
    end
    cutover.update!(backfilled_through_id: through_id) if after_id < through_id
  end

  desc "Compare PostgreSQL and ClickHouse heartbeat counts"
  task verify: :environment do
    abort "Set HEARTBEAT_WRITES_STOPPED=1 on every web and worker process" unless
      ENV["HEARTBEAT_WRITES_STOPPED"] == "1"
    abort "Set HEARTBEAT_MUTATIONS_STOPPED=1 on every web and worker process" unless
      ENV["HEARTBEAT_MUTATIONS_STOPPED"] == "1"
    cutover = HeartbeatCutover.find_by(id: 1)
    abort "Run clickhouse:backfill before verification" unless cutover
    abort "ClickHouse backfill has not reached its source boundary" unless
      cutover.backfilled_through_id >= cutover.source_through_id
    current_max_id = Heartbeat.postgresql_unscoped.maximum(:id).to_i
    abort "PostgreSQL received heartbeats after the recorded source boundary" unless
      current_max_id == cutover.source_through_id

    postgres = ActiveRecord::Base.connection.select_all(<<~SQL.squish).to_a.to_h do |row|
      SELECT source_type, deleted_at IS NOT NULL AS deleted, count(*) AS count,
             min(id) AS min_id, max(id) AS max_id, sum(id) AS id_sum
      FROM heartbeats GROUP BY source_type, deleted ORDER BY source_type, deleted
    SQL
      key = [ row.fetch("source_type").to_i, ActiveModel::Type::Boolean.new.cast(row.fetch("deleted")) ]
      [ key, row.slice("count", "min_id", "max_id", "id_sum").transform_values(&:to_i) ]
    end
    clickhouse_aggregates = %w[heartbeats heartbeats_by_time heartbeat_store].to_h do |table|
      canonical = table == "heartbeat_store" ? "WHERE canonicalized = true AND duplicate_of IS NULL" : ""
      rows = ClickHouse::Client.current.select(<<~SQL.squish).to_h do |row|
        SELECT source_type, deleted_at IS NOT NULL AS deleted, count() AS count,
               min(id) AS min_id, max(id) AS max_id, sum(id) AS id_sum
        FROM #{table} FINAL #{canonical}
        GROUP BY source_type, deleted ORDER BY source_type, deleted
      SQL
        key = [ row.fetch("source_type").to_i, ActiveModel::Type::Boolean.new.cast(row.fetch("deleted")) ]
        [ key, row.slice("count", "min_id", "max_id", "id_sum").transform_values(&:to_i) ]
      end
      [ table, rows ]
    end
    mismatched_table = clickhouse_aggregates.find { |_table, aggregate| aggregate != postgres }&.first
    abort "Heartbeat aggregate mismatch in #{mismatched_table}" if mismatched_table
    clickhouse = clickhouse_aggregates.fetch("heartbeats")

    pending = ClickHouse::Client.current.select(<<~SQL.squish).first.fetch("pending").to_i
      SELECT count() AS pending FROM heartbeat_store FINAL
      WHERE canonicalized = false OR (
        canonicalized = true AND duplicate_of IS NULL AND
        (heartbeats_version < version OR heartbeats_by_time_version < version)
      )
    SQL
    abort "ClickHouse heartbeat store has #{pending} pending rows" if pending.positive?
    incomplete_transfers = HeartbeatTransfer.where.not(status: :completed).count
    abort "Heartbeat transfers have #{incomplete_transfers} incomplete rows" if incomplete_transfers.positive?
    incomplete_deletions = HeartbeatDeletion.where.not(status: :completed).count
    abort "Heartbeat deletions have #{incomplete_deletions} incomplete rows" if incomplete_deletions.positive?
    incomplete_nullifications = HeartbeatJa4Nullification.where(completed_at: nil).count
    abort "Heartbeat JA4 nullifications have #{incomplete_nullifications} incomplete rows" if incomplete_nullifications.positive?

    columns = HeartbeatRepository::STORAGE_COLUMNS - [ "version" ]
    storage_columns = HeartbeatRepository::STORAGE_COLUMNS
    normalize_time = lambda do |value|
      value && Time.zone.parse(value.to_s).utc.strftime("%Y-%m-%d %H:%M:%S.%6N")
    end
    fingerprint = lambda do |rows, source, fingerprint_columns|
      digest = Digest::SHA256.new
      count = 0
      rows.each do |row|
        attributes = if source == :postgresql
          HeartbeatRepository.current.serialize_attributes(row.attributes)
        else
          row
        end
        attributes = attributes.slice(*fingerprint_columns)
        %w[created_at updated_at deleted_at].each do |column|
          attributes[column] = normalize_time.call(attributes[column])
        end
        payload = JSON.generate(fingerprint_columns.to_h { |column| [ column, attributes[column] ] })
        digest << [ payload.bytesize ].pack("Q>") << payload
        count += 1
      end
      [ count, digest.hexdigest ]
    end

    range_size = ENV.fetch("VERIFY_RANGE_SIZE", 10_000).to_i
    cursor = 0
    loop do
      postgres_rows = Heartbeat.postgresql_unscoped.where("id > ?", cursor).order(:id).limit(range_size).to_a
      break if postgres_rows.empty?

      start_id = postgres_rows.first.id
      end_id = postgres_rows.last.id
      repository = HeartbeatRepository.current
      identity_rows = repository.verification_rows(
        "heartbeat_store",
        postgres_rows,
        columns: HeartbeatRepository::STORE_COLUMNS
      )
      heartbeat_rows = repository.verification_rows("heartbeats", postgres_rows, columns: storage_columns)
      mirror_rows = repository.verification_rows("heartbeats_by_time", postgres_rows, columns: storage_columns)
      postgres_ids = postgres_rows.map(&:id)
      store_ids = identity_rows.pluck("id").map(&:to_i)
      clickhouse_ids = heartbeat_rows.pluck("id").map(&:to_i)
      mirror_ids = mirror_rows.pluck("id").map(&:to_i)
      unless [ postgres_ids, store_ids, clickhouse_ids, mirror_ids ].uniq.one?
        abort "Heartbeat ID mismatch for IDs #{start_id}-#{end_id}"
      end

      postgres_fingerprint = fingerprint.call(postgres_rows, :postgresql, columns)
      clickhouse_fingerprint = fingerprint.call(heartbeat_rows, :clickhouse, columns)
      mirror_fingerprint = fingerprint.call(mirror_rows, :clickhouse, columns)
      abort "Heartbeat row mismatch for IDs #{start_id}-#{end_id}" unless postgres_fingerprint == clickhouse_fingerprint
      abort "Heartbeat by-time mirror mismatch for IDs #{start_id}-#{end_id}" unless clickhouse_fingerprint == mirror_fingerprint

      store_fingerprint = fingerprint.call(identity_rows, :clickhouse, columns)
      abort "Canonical heartbeat store mismatch for IDs #{start_id}-#{end_id}" unless postgres_fingerprint == store_fingerprint

      invalid_payload = identity_rows.find do |row|
        row.fetch("payload_hash") != repository.send(:payload_hash, row)
      end
      abort "Canonical heartbeat payload hash mismatch for ID #{invalid_payload['id']}" if invalid_payload

      identity_keys = identity_rows.flat_map do |row|
        [ row.fetch("fields_hash"), *row.fetch("alias_hashes") ].uniq.map do |fields_hash|
          [ row.fetch("user_id").to_i, fields_hash, row ]
        end
      end
      aliases = identity_keys.group_by(&:first).flat_map do |user_id, keys|
        repository.send(:alias_rows, user_id, keys.pluck(1).uniq)
      end
      aliases_by_key = aliases.index_by { |row| [ row.fetch("user_id").to_i, row.fetch("fields_hash") ] }
      identity_keys.each do |user_id, fields_hash, row|
        alias_row = aliases_by_key[[ user_id, fields_hash ]]
        abort "Missing heartbeat alias for ID #{row.fetch('id')}" unless alias_row
        if row["deleted_at"].nil? &&
            (!alias_row.fetch("active") || alias_row.fetch("heartbeat_id").to_i != row.fetch("id").to_i)
          abort "Active heartbeat alias mismatch for ID #{row.fetch('id')}"
        end
      end
      target_keys = aliases.map { |row| [ row.fetch("user_id").to_i, row.fetch("heartbeat_id").to_i ] }.uniq
      targets = target_keys.each_slice(HeartbeatRepository::QUERY_BATCH_SIZE).flat_map do |keys|
        tuples = keys.map { |user_id, id| "(#{user_id}, #{id})" }.join(", ")
        ClickHouse::Client.current.select(<<~SQL.squish)
          SELECT user_id, id, fields_hash, alias_hashes, deleted_at FROM heartbeat_store FINAL
          WHERE canonicalized = true AND duplicate_of IS NULL AND (user_id, id) IN (#{tuples})
        SQL
      end.index_by { |row| [ row.fetch("user_id").to_i, row.fetch("id").to_i ] }
      aliases.each do |alias_row|
        key = [ alias_row.fetch("user_id").to_i, alias_row.fetch("heartbeat_id").to_i ]
        target = targets[key]
        hashes = target && [ target.fetch("fields_hash"), *target.fetch("alias_hashes") ]
        valid = target && hashes.include?(alias_row.fetch("fields_hash")) &&
          alias_row.fetch("active") == target["deleted_at"].nil?
        abort "Heartbeat alias points to invalid canonical state for ID #{key.last}" unless valid
      end

      clickhouse_storage_fingerprint = fingerprint.call(heartbeat_rows, :clickhouse, storage_columns)
      mirror_storage_fingerprint = fingerprint.call(mirror_rows, :clickhouse, storage_columns)
      unless clickhouse_storage_fingerprint == mirror_storage_fingerprint
        abort "Heartbeat by-time version mismatch for IDs #{start_id}-#{end_id}"
      end

      clickhouse_versions = heartbeat_rows.map do |row|
        [ row.fetch("id").to_i, row.fetch("version").to_i ]
      end
      store_versions = identity_rows.map do |row|
        [ row.fetch("id").to_i, row.fetch("version").to_i ]
      end
      abort "Canonical heartbeat version mismatch for IDs #{start_id}-#{end_id}" unless clickhouse_versions == store_versions
      puts "Verified heartbeat IDs #{start_id}-#{end_id}"
      cursor = end_id
    end

    invalid_aliases = ClickHouse::Client.current.select(<<~SQL.squish).first.fetch("invalid_aliases").to_i
      SELECT count() AS invalid_aliases
      FROM heartbeat_aliases AS aliases FINAL
      LEFT JOIN (
        SELECT user_id, id, fields_hash, alias_hashes, deleted_at
        FROM heartbeat_store FINAL
        WHERE canonicalized = true AND duplicate_of IS NULL
      ) AS canonical
        ON aliases.user_id = canonical.user_id AND aliases.heartbeat_id = canonical.id
      WHERE canonical.id IS NULL
        OR (aliases.fields_hash != canonical.fields_hash AND NOT has(canonical.alias_hashes, aliases.fields_hash))
        OR aliases.active != (canonical.deleted_at IS NULL)
      SETTINGS join_use_nulls = 1
    SQL
    abort "ClickHouse heartbeat aliases contain #{invalid_aliases} invalid rows" if invalid_aliases.positive?

    cutover.update!(verified_through_id: cutover.source_through_id, verified_at: Time.current)
    puts "Verified #{clickhouse.values.sum { |value| value.fetch('count') }} heartbeats"
  end

  desc "Reconcile the ClickHouse heartbeat store and both query layouts"
  task drain_outbox: :environment do
    mutation_fence = if ENV["HEARTBEAT_WRITES_STOPPED"] == "1"
      ENV.delete("HEARTBEAT_MUTATIONS_STOPPED")
    end
    begin
      loop do
        processed = HeartbeatRepository.current.reconcile_store(limit: 5_000)
        break if processed.zero?

        puts "Reconciled #{processed} ClickHouse heartbeat store rows"
      end
    ensure
      ENV["HEARTBEAT_MUTATIONS_STOPPED"] = mutation_fence if mutation_fence
    end
  end

  desc "Repair both query layouts solely from the canonical ClickHouse store"
  task repair_query_layouts: :environment do
    repository = HeartbeatRepository.current
    client = ClickHouse::Client.current
    columns = HeartbeatRepository::STORAGE_COLUMNS.join(", ")
    batch_size = ENV.fetch("BATCH_SIZE", HeartbeatRepository::INSERT_BATCH_SIZE).to_i
    abort "BATCH_SIZE must be positive" unless batch_size.positive?

    tables = ENV["TABLE"] ? [ ENV["TABLE"] ] : %w[heartbeats heartbeats_by_time]
    abort "TABLE must be heartbeats or heartbeats_by_time" unless
      (tables - %w[heartbeats heartbeats_by_time]).empty?

    requested_partition = ENV["PARTITION"]&.then { |value| Integer(value) }
    after_user_id = ENV.fetch("AFTER_USER_ID", 0).to_i
    after_id = ENV.fetch("AFTER_ID", 0).to_i
    if (after_user_id.positive? || after_id.positive?) && (!ENV["TABLE"] || !requested_partition)
      abort "Set TABLE and PARTITION when resuming from AFTER_USER_ID/AFTER_ID"
    end

    partitions = client.select(<<~SQL.squish).pluck("partition_id").map(&:to_i)
      SELECT DISTINCT toYYYYMM(created_at) AS partition_id
      FROM heartbeat_store FINAL
      WHERE canonicalized = true AND duplicate_of IS NULL
      ORDER BY partition_id
    SQL
    partitions.select! { |partition| partition == requested_partition } if requested_partition
    abort "No canonical rows exist in ClickHouse partition #{requested_partition}" if requested_partition && partitions.empty?

    tables.each do |table|
      partitions.each do |partition|
        cursor_user_id = requested_partition ? after_user_id : 0
        cursor_id = requested_partition ? after_id : 0
        loop do
          rows = client.select(<<~SQL.squish)
            SELECT #{columns} FROM heartbeat_store FINAL
            WHERE canonicalized = true AND duplicate_of IS NULL
              AND toYYYYMM(created_at) = #{partition}
              AND (user_id, id) > (#{cursor_user_id}, #{cursor_id})
            ORDER BY user_id, id LIMIT #{batch_size}
          SQL
          break if rows.empty?

          repository.insert_rows(table, rows)
          repository.verify_visible_versions!(table, rows)
          cursor_user_id = rows.last.fetch("user_id").to_i
          cursor_id = rows.last.fetch("id").to_i
          puts "Repaired #{table} through partition #{partition}, user #{cursor_user_id}, heartbeat #{cursor_id}"
        end
        after_user_id = after_id = 0
      end
    end
  end

  desc "Advance PostgreSQL heartbeat allocators past every ClickHouse ID and version"
  task reseed_postgres_sequences: :environment do
    abort "Set HEARTBEAT_STORE=clickhouse" unless HeartbeatRepository.clickhouse?
    abort "Set HEARTBEAT_WRITES_STOPPED=1 on every web and worker process" unless
      ENV["HEARTBEAT_WRITES_STOPPED"] == "1"
    abort "Set HEARTBEAT_MUTATIONS_STOPPED=1 on every web and worker process" unless
      ENV["HEARTBEAT_MUTATIONS_STOPPED"] == "1"

    HeartbeatRepository.current.reseed_postgres_sequences!.each do |sequence, value|
      puts "Advanced #{sequence} through #{value}"
    end
  end

  desc "Replay durable PostgreSQL lifecycle controls after restoring a ClickHouse backup"
  task replay_lifecycle_controls: :environment do
    abort "Set HEARTBEAT_STORE=clickhouse" unless HeartbeatRepository.clickhouse?
    abort "Set HEARTBEAT_WRITES_STOPPED=1 on every web and worker process" unless
      ENV["HEARTBEAT_WRITES_STOPPED"] == "1"
    abort "Set HEARTBEAT_MUTATIONS_STOPPED=1 on every web and worker process" unless
      ENV["HEARTBEAT_MUTATIONS_STOPPED"] == "1"
    scoped_repair_variables = %w[TABLE PARTITION AFTER_USER_ID AFTER_ID].select { |name| ENV[name].present? }
    abort "Unset #{scoped_repair_variables.join(', ')} before lifecycle recovery" if scoped_repair_variables.any?

    transfers = HeartbeatTransfer.order(:delete_version, :id).to_a
    deletions = HeartbeatDeletion.order(:clickhouse_version, :id).to_a
    nullifications = HeartbeatJa4Nullification.order(:clickhouse_version, :id).to_a
    unfinished = transfers.count { |control| !control.completed? || !control.copied_at? || !control.completed_at? } +
      deletions.count { |control| !control.completed? || !control.completed_at? } +
      nullifications.count { |control| !control.completed_at? }
    abort "Complete all heartbeat lifecycle controls before recovery (#{unfinished} unfinished)" if unfinished.positive?

    Rake::Task["clickhouse:reseed_postgres_sequences"].reenable
    Rake::Task["clickhouse:reseed_postgres_sequences"].invoke

    mutation_fence = ENV.delete("HEARTBEAT_MUTATIONS_STOPPED")
    begin
      repository = HeartbeatRepository.current
      transfers.each do |transfer|
        repository.transfer_rows(transfer, reconcile_nullifications: false)
        puts "Replayed heartbeat transfer #{transfer.id}"
      end
      deletions.each do |deletion|
        repository.soft_delete_user(
          deletion.user_id,
          version: deletion.clickhouse_version,
          deleted_at: deletion.created_at,
          nullifications_through: deletion.clickhouse_version
        )
        puts "Replayed heartbeat deletion #{deletion.id}"
      end
      nullifications.each do |nullification|
        repository.nullify_ja4(
          nullification.ja4_id,
          version: nullification.clickhouse_version,
          superseded_deletion: :skip
        )
        puts "Replayed heartbeat JA4 nullification #{nullification.id}"
      end

      Rake::Task["clickhouse:drain_outbox"].reenable
      Rake::Task["clickhouse:drain_outbox"].invoke
      Rake::Task["clickhouse:repair_query_layouts"].reenable
      Rake::Task["clickhouse:repair_query_layouts"].invoke
      Rake::Task["clickhouse:drain_outbox"].reenable
      Rake::Task["clickhouse:drain_outbox"].invoke

      client = ClickHouse::Client.current
      transfers.map(&:from_user_id).uniq.each_slice(HeartbeatRepository::QUERY_BATCH_SIZE) do |user_ids|
        active = client.select(<<~SQL.squish).first.fetch("active_rows").to_i
          SELECT count() AS active_rows FROM heartbeat_store FINAL
          WHERE canonicalized = true AND duplicate_of IS NULL AND deleted_at IS NULL
            AND user_id IN (#{user_ids.join(', ')})
        SQL
        abort "Recovery left #{active} active heartbeats for transferred users" if active.positive?
      end
      deletions.map(&:user_id).uniq.each_slice(HeartbeatRepository::QUERY_BATCH_SIZE) do |user_ids|
        active = client.select(<<~SQL.squish).first.fetch("active_rows").to_i
          SELECT count() AS active_rows FROM heartbeat_store FINAL
          WHERE canonicalized = true AND duplicate_of IS NULL AND deleted_at IS NULL
            AND user_id IN (#{user_ids.join(', ')})
        SQL
        abort "Recovery left #{active} active heartbeats for deleted users" if active.positive?
      end
      nullifications.map(&:ja4_id).uniq.each_slice(HeartbeatRepository::QUERY_BATCH_SIZE) do |ja4_ids|
        retained = client.select(<<~SQL.squish).first.fetch("retained_rows").to_i
          SELECT count() AS retained_rows FROM heartbeat_store FINAL
          WHERE duplicate_of IS NULL AND ja4_id IN (#{ja4_ids.join(', ')})
        SQL
        abort "Recovery left #{retained} heartbeats with deleted JA4 records" if retained.positive?
      end
      pending = client.select(<<~SQL.squish).first.fetch("pending_rows").to_i
        SELECT count() AS pending_rows FROM heartbeat_store FINAL
        WHERE canonicalized = false OR (canonicalized = true AND duplicate_of IS NULL AND
          (heartbeats_version < version OR heartbeats_by_time_version < version))
      SQL
      abort "Recovery left #{pending} canonical or delivery rows pending" if pending.positive?

      puts "Replayed and verified all durable heartbeat lifecycle controls"
    ensure
      ENV["HEARTBEAT_MUTATIONS_STOPPED"] = mutation_fence
    end
  end

  desc "Permanently remove legacy PostgreSQL heartbeat storage after verified cutover"
  task purge_postgres: :environment do
    abort "Set HEARTBEAT_STORE=clickhouse" unless HeartbeatRepository.clickhouse?
    abort "Set HEARTBEAT_WRITES_STOPPED=1 on every web and worker process" unless
      ENV["HEARTBEAT_WRITES_STOPPED"] == "1"
    abort "Set HEARTBEAT_MUTATIONS_STOPPED=1 on every web and worker process" unless
      ENV["HEARTBEAT_MUTATIONS_STOPPED"] == "1"

    Rake::Task["clickhouse:drain_outbox"].reenable
    Rake::Task["clickhouse:drain_outbox"].invoke
    Rake::Task["clickhouse:verify"].reenable
    Rake::Task["clickhouse:verify"].invoke
    cutover = HeartbeatCutover.find(1)
    abort "The recorded ClickHouse verification is stale" unless
      cutover.verified_through_id == cutover.source_through_id && cutover.verified_at?

    ActiveRecord::Base.connection.execute("TRUNCATE TABLE heartbeats, dashboard_rollups")
    User.update_all(dashboard_rollup_generation: 0, dashboard_rollup_refreshed_generation: 0)
    cutover.update!(purged_at: Time.current)
    puts "Removed all PostgreSQL heartbeat payloads and dashboard rollups"
  end
end
