require "test_helper"

class HeartbeatIngestClickHouseConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    skip "Set CLICKHOUSE_INTEGRATION=1 to run" unless ENV["CLICKHOUSE_INTEGRATION"] == "1"

    @previous_repository = HeartbeatRepository.instance_variable_get(:@current)
    @previous_test_setting = ENV["CLICKHOUSE_TEST"]
    ENV["CLICKHOUSE_TEST"] = "1"
    @database = "hackatime_concurrency_test_#{Process.pid}_#{SecureRandom.hex(4)}"
    @admin = ClickHouse::Client.current
    @admin.execute("CREATE DATABASE #{@database}")
    @client = ClickHouse::Client.new(ENV.fetch("CLICKHOUSE_URL").sub(%r{/[^/]+\z}, "/#{@database}"))
    %w[
      001_create_heartbeats.sql
      009_create_heartbeats_by_time.sql
      012_create_heartbeat_store.sql
      013_create_heartbeat_aliases.sql
    ].each { |file| @client.execute(File.read(Rails.root.join("db/clickhouse", file))) }
    HeartbeatRepository.instance_variable_set(:@current, HeartbeatRepository.new(client: @client))
    @user = User.create!(timezone: "UTC")
  end

  teardown do
    @user&.destroy!
    @admin&.execute("DROP DATABASE IF EXISTS #{@database}") if @database
    ENV["CLICKHOUSE_TEST"] = @previous_test_setting
    HeartbeatRepository.instance_variable_set(:@current, @previous_repository)
  end

  test "concurrent direct ingestion reserves one identity" do
    heartbeat = { entity: "race.rb", time: Time.current.to_f, type: "file" }

    results = concurrently do |user|
      HeartbeatIngest.call(
        user:,
        mode: :direct,
        heartbeats: [ heartbeat ],
        schedule_rollup_refresh: false
      )
    end

    assert_equal 1, results.sum(&:persisted_count)
    assert_equal 1, results.sum(&:duplicate_count)
    assert_equal 1, @client.select(<<~SQL.squish).first.fetch("count").to_i
      SELECT count() AS count FROM heartbeat_store FINAL
      WHERE user_id = #{@user.id} AND canonicalized = true AND duplicate_of IS NULL
    SQL
    assert_equal 2, @client.select("SELECT count() AS count FROM heartbeat_aliases FINAL WHERE active").first.fetch("count").to_i
  end

  test "concurrent imports reserve one canonical and legacy identity" do
    heartbeat = {
      entity: "race.rb",
      project: "migration",
      language: "Ruby",
      time: Time.current.to_f,
      type: "file"
    }

    results = concurrently do |user|
      HeartbeatIngest.call(
        user:,
        mode: :import,
        heartbeats: [ heartbeat ],
        schedule_rollup_refresh: false
      )
    end

    assert_equal 1, results.sum(&:persisted_count)
    assert_equal 1, results.sum(&:duplicate_count)
    assert_equal 1, @client.select(<<~SQL.squish).first.fetch("count").to_i
      SELECT count() AS count FROM heartbeat_store FINAL
      WHERE user_id = #{@user.id} AND canonicalized = true AND duplicate_of IS NULL
    SQL
    store = @client.select(<<~SQL.squish).sole
      SELECT fields_hash, alias_hashes FROM heartbeat_store FINAL
      WHERE user_id = #{@user.id} AND canonicalized = true AND duplicate_of IS NULL
    SQL
    expected_aliases = [ store.fetch("fields_hash"), *store.fetch("alias_hashes") ].uniq.length
    assert_equal expected_aliases,
      @client.select("SELECT count() AS count FROM heartbeat_aliases FINAL WHERE active").first.fetch("count").to_i
  end

  private

  def concurrently(&work)
    ready = Queue.new
    start = Queue.new
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          user = User.find(@user.id)
          ready << true
          start.pop
          work.call(user)
        end
      end
    end
    2.times { ready.pop }
    2.times { start << true }
    threads.map(&:value)
  end
end
