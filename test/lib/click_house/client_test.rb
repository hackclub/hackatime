require "test_helper"

class ClickHouse::ClientTest < ActiveSupport::TestCase
  class FailingConnection
    attr_reader :finished

    def initialize(error)
      @error = error
    end

    def request(*) = raise(@error)
    def active? = true
    def finish = @finished = true
  end

  test "transport failures close the persistent connection" do
    [ Timeout::Error.new("timed out"), Errno::ECONNRESET.new ].each do |error|
      connection = FailingConnection.new(error)
      client = ClickHouse::Client.new("http://default:@clickhouse:8123/hackatime_test")
      client.singleton_class.define_method(:connection) do
        Thread.current[@connection_key] ||= connection
      end

      assert_raises(error.class) { client.select("SELECT 1") }

      assert connection.finished
      key = client.instance_variable_get(:@connection_key)
      assert_nil Thread.current[key]
    end
  end

  test "JSON inserts preserve the exact IEEE-754 value" do
    client = ClickHouse::Client.new("http://default:@clickhouse:8123/hackatime_test")
    value = 1_786_463_014.4097862

    decimal = client.send(:serialize_json_value, { "time" => value }).fetch("time")

    assert_equal value, Float(decimal)
    assert_operator decimal.length, :>, value.to_s.length
  end
end
