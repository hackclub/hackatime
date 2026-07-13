require "monitor"

module ClickhouseConnectionThreadSafety
  DEFAULT_FORMAT = Object.new.freeze

  def initialize(...)
    super
    @clickhouse_connection_lock = Monitor.new
  end

  def execute(sql, name = nil, format: DEFAULT_FORMAT, settings: {})
    clickhouse_connection_lock.synchronize do
      format = @response_format if format.equal?(DEFAULT_FORMAT)
      super(sql, name, format: format, settings: settings)
    end
  end

  def execute_to_file(sql, name = nil, format: DEFAULT_FORMAT, settings: {})
    clickhouse_connection_lock.synchronize do
      format = @response_format if format.equal?(DEFAULT_FORMAT)
      super(sql, name, format: format, settings: settings)
    end
  end

  def with_settings(**, &)
    clickhouse_connection_lock.synchronize { super }
  end

  def with_clickhouse_read_timeout(seconds)
    clickhouse_connection_lock.synchronize do
      previous_timeout = @connection.read_timeout
      @connection.read_timeout = seconds
      yield
    ensure
      @connection.read_timeout = previous_timeout
    end
  end

  private

  def clickhouse_connection_lock
    @clickhouse_connection_lock ||= Monitor.new
  end
end

ActiveRecord::ConnectionAdapters::ClickhouseAdapter.prepend(ClickhouseConnectionThreadSafety)
