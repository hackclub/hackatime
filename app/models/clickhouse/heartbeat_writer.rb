module Clickhouse
  # The only write path for heartbeats. Heartbeats live exclusively in
  # ClickHouse; nothing writes them to Postgres anymore.
  #
  # Dedup model: rows sharing the ReplacingMergeTree ORDER BY key
  # (user_id, time, fields_hash) collapse eventually, keeping the highest
  # version. Soft deletes and merges are new row versions, never mutations.
  module HeartbeatWriter
    WRITABLE_COLUMNS = %w[
      id user_id time fields_hash project branch entity category editor
      language machine operating_system type user_agent ip_address dependencies
      lineno lines cursorpos line_additions line_deletions project_root_count
      is_write source_type ja4_id deleted_at created_at updated_at version
    ].freeze

    class << self
      # JS-safe snowflake: (epoch seconds << 22) | 22 random bits stays under
      # 2**53 until 2038. Collisions are harmless: id is not a dedup key, only
      # an attribution tie-breaker.
      def generate_id(time = Time.current)
        (time.to_i << 22) | SecureRandom.random_number(1 << 22)
      end

      def generate_version(time = Time.current)
        (time.to_r * 1_000_000).to_i
      end

      def create!(attrs)
        rows = insert_rows([ attrs ])
        rows.first
      end

      def insert_rows(attribute_hashes, maintain_serving_tables: true)
        rows = attribute_hashes.map { |attributes| shape_row(attributes) }
        return rows if rows.empty?

        if maintain_serving_tables
          HeartbeatIntervals::UserLock.call(user_ids: rows.pluck("user_id")) do
            persist_rows(rows, maintain_serving_tables: true)
          end
        else
          persist_rows(rows, maintain_serving_tables: false)
        end
        rows
      end

      # Server-side bulk soft delete: re-insert every live row for the user
      # with deleted_at set and a fresh version.
      def soft_delete_user_heartbeats!(user_id)
        HeartbeatIntervals::UserLock.call(user_ids: [ user_id ]) do
          connection = Clickhouse::Heartbeat.connection
          table = connection.quote_table_name(Clickhouse::Heartbeat.table_name)
          version = generate_version

          exprs = WRITABLE_COLUMNS.map do |column|
            case column
            when "deleted_at" then "now64(6)"
            when "version" then version.to_s
            else connection.quote_column_name(column)
            end
          end
          connection.execute(<<~SQL.squish)
            INSERT INTO #{table} (#{column_list(connection)})
            SELECT #{exprs.join(", ")} FROM #{table} FINAL
            WHERE user_id = #{user_id.to_i} AND deleted_at IS NULL
          SQL
          clear_query_cache
          HeartbeatIntervals::UserRebuilder.call(user_id: user_id, reason: "soft_delete_user")
          clear_query_cache
        end
      end

      # Account merge: copy the newer user's live rows to the older user, then
      # tombstone everything left under the newer user. Idempotent — re-running
      # re-inserts identical rows which ReplacingMergeTree collapses.
      def merge_user_heartbeats!(older_user_id:, newer_user_id:)
        user_ids = [ older_user_id.to_i, newer_user_id.to_i ]
        HeartbeatIntervals::UserLock.call(user_ids: user_ids) do
          connection = Clickhouse::Heartbeat.connection
          table = connection.quote_table_name(Clickhouse::Heartbeat.table_name)
          version = generate_version

          moved_exprs = WRITABLE_COLUMNS.map do |column|
            column == "user_id" ? older_user_id.to_i.to_s : connection.quote_column_name(column)
          end
          connection.execute(<<~SQL.squish)
            INSERT INTO #{table} (#{column_list(connection)})
            SELECT #{moved_exprs.join(", ")} FROM #{table} FINAL
            WHERE user_id = #{newer_user_id.to_i} AND deleted_at IS NULL
          SQL

          tombstone_exprs = WRITABLE_COLUMNS.map do |column|
            case column
            when "deleted_at" then "now64(6)"
            when "version" then version.to_s
            else connection.quote_column_name(column)
            end
          end
          connection.execute(<<~SQL.squish)
            INSERT INTO #{table} (#{column_list(connection)})
            SELECT #{tombstone_exprs.join(", ")} FROM #{table} FINAL
            WHERE user_id = #{newer_user_id.to_i} AND deleted_at IS NULL
          SQL
          clear_query_cache
        end
        enqueue_rebuild!(user_ids, reason: "merge_user")
      rescue => error
        Rails.error.report(error, handled: true, context: { message: "Serving rebuild enqueue failed after account merge" })
        user_ids.each { |user_id| HeartbeatIntervals::UserRebuilder.call(user_id: user_id, reason: "merge_user_recovery") }
      end

      private

      def persist_rows(rows, maintain_serving_tables:)
        serving_changes = classify_serving_changes(rows) if maintain_serving_tables
        Clickhouse::Heartbeat.unscoped.insert_all(rows)
        raw_rows_persisted = true
        clear_query_cache
        apply_serving_changes(serving_changes) if serving_changes
        clear_query_cache
      rescue
        enqueue_rebuild(rows.pluck("user_id"), reason: "heartbeat_write_recovery") if raw_rows_persisted && maintain_serving_tables
        raise
      end

      def classify_serving_changes(rows)
        incoming_rows = rows.group_by { |row| serving_key(row) }
          .values
          .map { |versions| versions.max_by { |row| row["version"].to_i } }
        existing_by_key = existing_rows_by_key(incoming_rows)
        max_time_by_user = existing_max_time_by_user(incoming_rows)
        rebuild_user_ids = Set.new
        appended_rows = []

        incoming_rows.each do |row|
          existing = existing_by_key[serving_key(row)]
          if existing
            next if row["version"].to_i <= existing["version"].to_i

            rebuild_user_ids << row["user_id"].to_i if live_row?(row) != live_row?(existing)
          elsif live_valid_row?(row)
            user_id = row["user_id"].to_i
            if max_time_by_user[user_id] && row["time"].to_f <= max_time_by_user[user_id].to_f
              rebuild_user_ids << user_id
            else
              appended_rows << row
            end
          end
        end

        { appended_rows: appended_rows, rebuild_user_ids: rebuild_user_ids }
      end

      def apply_serving_changes(changes)
        rebuild_user_ids = changes.fetch(:rebuild_user_ids)
        appended_rows = changes.fetch(:appended_rows).reject do |row|
          rebuild_user_ids.include?(row["user_id"].to_i)
        end

        HeartbeatIntervals::DeltaWriter.emit_for_inserted_rows(appended_rows, reason: "heartbeat_insert") if appended_rows.any?
        rebuild_user_ids.each do |user_id|
          HeartbeatIntervals::UserRebuilder.call(user_id: user_id, reason: "heartbeat_change")
        end
      end

      def enqueue_rebuild(user_ids, reason:)
        enqueue_rebuild!(user_ids, reason: reason)
      rescue => error
        Rails.error.report(error, handled: true, context: { message: "Serving rebuild recovery enqueue failed", user_ids: user_ids })
      end

      def enqueue_rebuild!(user_ids, reason:)
        job = HeartbeatServingRebuildJob.perform_later(Array(user_ids).map(&:to_i).uniq, reason: reason)
        raise ActiveJob::EnqueueError, "Serving rebuild job was not enqueued" unless job

        job
      end

      def existing_rows_by_key(rows)
        user_ids = rows.map { |row| row["user_id"].to_i }.uniq
        fields_hashes = rows.map { |row| row["fields_hash"] }.uniq

        Clickhouse::Heartbeat.unscoped.final
          .where(user_id: user_ids, fields_hash: fields_hashes)
          .pluck(:user_id, :fields_hash, :version, :deleted_at)
          .to_h do |user_id, fields_hash, version, deleted_at|
            [ [ user_id.to_i, fields_hash ], { "version" => version, "deleted_at" => deleted_at } ]
          end
      end

      def existing_max_time_by_user(rows)
        user_ids = rows.map { |row| row["user_id"].to_i }.uniq
        Clickhouse::Heartbeat.unscoped.final
          .where(deleted_at: nil, user_id: user_ids)
          .with_valid_timestamps
          .group(:user_id)
          .maximum(:time)
          .transform_keys(&:to_i)
      end

      def serving_key(row)
        [ row["user_id"].to_i, row["fields_hash"] ]
      end

      def live_row?(row)
        row["deleted_at"].blank?
      end

      def live_valid_row?(row)
        live_row?(row) && row["time"].present? && HeartbeatIntervals::VALID_TIME_RANGE.cover?(row["time"].to_f)
      end

      def column_list(connection)
        WRITABLE_COLUMNS.map { |column| connection.quote_column_name(column) }.join(", ")
      end

      # The ClickHouse adapter's insert paths don't invalidate Rails' query
      # cache, so reads issued after a write inside the same executor frame
      # (request/job/test) would return stale results.
      def clear_query_cache
        Clickhouse::Heartbeat.connection.clear_query_cache
      end

      def shape_row(attributes)
        attrs = attributes.transform_keys(&:to_s)
        now = Time.current
        created_at = attrs["created_at"] || now
        updated_at = attrs["updated_at"] || created_at
        deleted_at = attrs["deleted_at"]
        time = attrs["time"]&.to_f

        row = WRITABLE_COLUMNS.index_with { |column| attrs[column] }
        row["id"] = attrs["id"] || generate_id(now)
        row["time"] = time
        row["fields_hash"] = attrs["fields_hash"].presence || Clickhouse::Heartbeat.generate_fields_hash(attrs)
        row["ip_address"] = attrs["ip_address"]&.to_s
        row["dependencies"] = Array(attrs["dependencies"]).map(&:to_s)
        row["source_type"] = shape_source_type(attrs["source_type"])
        row["is_write"] = attrs["is_write"].nil? ? nil : Clickhouse::Heartbeat.send(:cast_boolean, attrs["is_write"])
        row["created_at"] = created_at
        row["updated_at"] = updated_at
        row["deleted_at"] = deleted_at
        version_time = [ updated_at, deleted_at ].compact.max
        row["version"] = attrs["version"] || generate_version(version_time)
        row
      end

      def shape_source_type(value)
        value.presence || "direct_entry"
      end
    end
  end
end
