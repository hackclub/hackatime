module ClickhouseActiverecord
  class Settings
    # The app reads freshly written heartbeats immediately for stats, caches, and tests.
    # Use synchronous inserts so subsequent queries see the rows deterministically.
    def insert_settings
      { wait_for_async_insert: 1, async_insert: 0 }
    end
  end

  class SchemaDumper
    private

    def schema_type(column)
      sql_type = column.sql_type.to_s.delete_prefix("Nullable(").delete_suffix(")")
      return :float64 if column.type == :float && sql_type == "Float64"

      super
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    class ClickhouseAdapter
      FLOAT64_DATABASE_TYPES = { float64: { name: "Float64" } }.freeze

      class << self
        def native_database_types
          self::NATIVE_DATABASE_TYPES.merge(FLOAT64_DATABASE_TYPES)
        end

        def valid_type?(type)
          native_database_types[type].present?
        end
      end

      def native_database_types
        self.class.native_database_types
      end

      def valid_type?(type)
        self.class.valid_type?(type)
      end
    end

    module Clickhouse
      class TableDefinition
        def float64(*args, **options)
          args.each { |name| column(name, :float64, **options) }
        end
      end
    end
  end
end
