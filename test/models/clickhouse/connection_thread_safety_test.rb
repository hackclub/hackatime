require "test_helper"

class Clickhouse::ConnectionThreadSafetyTest < ActiveSupport::TestCase
  test "serializes mixed response formats on one persistent HTTP connection" do
    connection = Clickhouse::Record.connection
    errors = Queue.new
    values = Queue.new

    threads = [
      Thread.new do
        100.times { connection.execute("SELECT 1", format: nil) }
      rescue => e
        errors << e
      end,
      Thread.new do
        100.times { values << connection.select_value("SELECT 1").to_i }
      rescue => e
        errors << e
      end
    ]
    threads.each(&:join)

    flunk errors.pop.full_message unless errors.empty?
    assert_equal [ 1 ] * 100, 100.times.map { values.pop }
  end

  test "scoped read timeout restores the persistent connection timeout" do
    connection = Clickhouse::Record.connection
    http = connection.instance_variable_get(:@connection)
    original_timeout = http.read_timeout

    connection.with_clickhouse_read_timeout(original_timeout + 1) do
      assert_equal original_timeout + 1, http.read_timeout
    end

    assert_equal original_timeout, http.read_timeout
  end
end
