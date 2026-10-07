# ClickHouse has no transactions, so Rails' transactional tests cannot roll it
# back. Every ClickHouse table is truncated before each test instead.
module ClickhouseTestDatabase
  RAILS_TABLES = %w[schema_migrations ar_internal_metadata].freeze

  module_function

  def reset!
    allow_through_webmock!
    connection = ClickhouseRecord.connection
    database = connection.select_value("SELECT currentDatabase()")
    raise "refusing to truncate ClickHouse database #{database}" unless database.start_with?("hackatime_test")

    (connection.tables - RAILS_TABLES).each { |table| connection.execute("TRUNCATE TABLE #{connection.quote_table_name(table)}") }
  end

  # Some test files load WebMock and block real HTTP. ClickHouse is reached
  # over HTTP, so keep its host allowed whatever they configure.
  def allow_through_webmock!
    return unless defined?(WebMock::Config)

    host = ClickhouseRecord.connection_db_config.configuration_hash[:host]
    allowed = Array(WebMock::Config.instance.allow)
    WebMock::Config.instance.allow = allowed + [ host ] unless allowed.include?(host)
  end
end
