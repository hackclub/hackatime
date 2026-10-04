# Isolates ClickHouse state in tests. ClickHouse has no transactions, so Rails'
# transactional tests cannot roll it back. Instead each test process (and each
# parallel worker) gets its own database, created from db/clickhouse/*.sql, and
# every ClickHouse table is truncated before each test.
module ClickhouseTestDatabase
  BASE = ENV.fetch("CLICKHOUSE_TEST_DATABASE", "hackatime_test")
  RUN_ID = ENV.fetch("CLICKHOUSE_TEST_RUN_ID") { "#{Process.pid}_#{SecureRandom.hex(3)}" }

  module_function

  def name_for(worker = nil) = [ BASE, RUN_ID, worker ].compact.join("_")

  # Points ClickhouseRecord at a fresh database for this process and loads the schema.
  def setup!(worker = nil)
    database = name_for(worker)
    raise "refusing to use non-test ClickHouse database #{database}" unless database.start_with?("hackatime_test")

    base = ClickhouseRecord.connection_db_config.configuration_hash
    # The adapter sends every request with the configured database selected, so
    # the test database has to be created from a connection to `default`.
    ClickhouseRecord.establish_connection(base.merge(database: "default"))
    ClickhouseRecord.connection.execute("CREATE DATABASE IF NOT EXISTS #{ClickhouseRecord.connection.quote_table_name(database)}")
    ClickhouseRecord.establish_connection(base.merge(database:))
    connection = ClickhouseRecord.connection
    ClickhouseSchema.load!(connection)
    at_exit { drop!(database) }
    @database = database
  end

  def reset!
    allow_through_webmock!
    connection = ClickhouseRecord.connection
    current = connection.select_value("SELECT currentDatabase()")
    raise "refusing to truncate ClickHouse database #{current}" unless current == @database

    ClickhouseSchema.table_names.each { |table| connection.execute("TRUNCATE TABLE IF EXISTS #{connection.quote_table_name(table)}") }
  end

  # Some test files load WebMock and block real HTTP. ClickHouse is reached
  # over HTTP, so keep its host allowed whatever they configure.
  def allow_through_webmock!
    return unless defined?(WebMock::Config)

    host = ClickhouseRecord.connection_db_config.configuration_hash[:host]
    allowed = Array(WebMock::Config.instance.allow)
    WebMock::Config.instance.allow = allowed + [ host ] unless allowed.include?(host)
  end

  def drop!(database)
    ClickhouseRecord.connection.execute("DROP DATABASE IF EXISTS #{ClickhouseRecord.connection.quote_table_name(database)} SYNC")
  rescue StandardError => e
    warn "Could not drop ClickHouse test database #{database}: #{e.message}"
  end
end
