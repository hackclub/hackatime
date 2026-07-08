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

      def create!(attrs)
        rows = insert_rows([ attrs ])
        rows.first
      end

      def insert_rows(attribute_hashes)
        rows = attribute_hashes.map { |attributes| shape_row(attributes) }
        if rows.any?
          Clickhouse::Heartbeat.unscoped.insert_all(rows)
          clear_query_cache
        end
        rows
      end

      # Server-side bulk soft delete: re-insert every live row for the user
      # with deleted_at set and a fresh version.
      def soft_delete_user_heartbeats!(user_id)
        connection = Clickhouse::Heartbeat.connection
        table = connection.quote_table_name(Clickhouse::Heartbeat.table_name)
        version = (Time.current.to_f * 1_000_000).round

        exprs = WRITABLE_COLUMNS.map do |column|
          case column
          when "deleted_at" then "now64(6)"
          when "version" then version.to_s
          else connection.quote_column_name(column)
          end
        end
        connection.execute(<<~SQL.squish)
          INSERT INTO #{table} (#{column_list(connection)})
          SELECT #{exprs.join(", ")} FROM #{table}
          WHERE user_id = #{user_id.to_i} AND deleted_at IS NULL
        SQL
        clear_query_cache
      end

      # Account merge: copy the newer user's live rows to the older user, then
      # tombstone everything left under the newer user. Idempotent — re-running
      # re-inserts identical rows which ReplacingMergeTree collapses.
      def merge_user_heartbeats!(older_user_id:, newer_user_id:)
        connection = Clickhouse::Heartbeat.connection
        table = connection.quote_table_name(Clickhouse::Heartbeat.table_name)
        version = (Time.current.to_f * 1_000_000).round

        moved_exprs = WRITABLE_COLUMNS.map do |column|
          column == "user_id" ? older_user_id.to_i.to_s : connection.quote_column_name(column)
        end
        connection.execute(<<~SQL.squish)
          INSERT INTO #{table} (#{column_list(connection)})
          SELECT #{moved_exprs.join(", ")} FROM #{table}
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
          SELECT #{tombstone_exprs.join(", ")} FROM #{table}
          WHERE user_id = #{newer_user_id.to_i} AND deleted_at IS NULL
        SQL
        clear_query_cache
      end

      private

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
        row["version"] = attrs["version"] || (version_time.to_f * 1_000_000).round
        row
      end

      def shape_source_type(value)
        return 0 if value.nil?
        return value if value.is_a?(Integer)

        Clickhouse::Heartbeat.source_types.fetch(value.to_s, 0)
      end
    end
  end
end
