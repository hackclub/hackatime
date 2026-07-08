module Clickhouse
  module HeartbeatMirror
    COPIED_COLUMNS = %w[
      id user_id time type project branch category editor entity language machine
      operating_system user_agent lineno lines cursorpos line_additions
      line_deletions project_root_count is_write ip_address ja4_id fields_hash
      created_at updated_at
    ].freeze

    class << self
      def enabled?
        return @active unless @active.nil?

        Rails.env.development? || Rails.env.test?
      end

      def with_mirroring(active = true)
        previous = @active
        @active = active
        yield
      ensure
        @active = previous
      end

      def upsert(heartbeat)
        return unless enabled?

        insert_rows([ row_for(heartbeat) ])
      end

      def upsert_rows(attribute_hashes)
        return unless enabled?

        rows = attribute_hashes.map { |attributes| shape_row(attributes) }
        insert_rows(rows) if rows.any?
      end

      def backfill(scope = ::Heartbeat.with_deleted, batch_size: 10_000)
        scope.in_batches(of: batch_size) do |relation|
          rows = relation.map { |heartbeat| row_for(heartbeat) }
          insert_rows(rows) if rows.any?
        end
      end

      def insert_rows(rows)
        Clickhouse::Heartbeat.unscoped.insert_all(rows)
      end

      def row_for(heartbeat) = shape_row(heartbeat.attributes)

      private

      def shape_row(attributes)
        row = COPIED_COLUMNS.index_with { |column| attributes[column] }
        row["ip_address"] = attributes["ip_address"]&.to_s
        row["dependencies"] = shape_dependencies(attributes["dependencies"])
        row["source_type"] = shape_source_type(attributes["source_type"])
        row["deleted_at"] = attributes["deleted_at"]
        version_time = [ attributes["updated_at"], attributes["deleted_at"] ].compact.max
        row["version"] = (version_time.to_f * 1_000_000).round
        row
      end

      def shape_dependencies(value)
        value = ::Heartbeat.attribute_types["dependencies"].deserialize(value) if value.is_a?(String)
        Array(value)
      end

      def shape_source_type(value)
        value.is_a?(Integer) ? value : ::Heartbeat.source_types.fetch(value, 0)
      end
    end
  end
end
