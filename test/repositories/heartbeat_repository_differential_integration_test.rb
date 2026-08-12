require "test_helper"
require "rake"

class HeartbeatRepositoryDifferentialIntegrationTest < ActiveSupport::TestCase
  setup do
    skip "Set CLICKHOUSE_INTEGRATION=1 to run" unless ENV["CLICKHOUSE_INTEGRATION"] == "1"

    @previous_repository = HeartbeatRepository.instance_variable_get(:@current)
    @previous_client = ClickHouse::Client.instance_variable_get(:@current)
    @previous_test_setting = ENV["CLICKHOUSE_TEST"]
    @database = "hackatime_differential_test_#{Process.pid}_#{SecureRandom.hex(4)}"
    @admin = ClickHouse::Client.current
    @admin.execute("CREATE DATABASE #{@database}")
    @client = ClickHouse::Client.new(ENV.fetch("CLICKHOUSE_URL").sub(%r{/[^/]+\z}, "/#{@database}"))
    %w[
      001_create_heartbeats.sql
      009_create_heartbeats_by_time.sql
      012_create_heartbeat_store.sql
      013_create_heartbeat_aliases.sql
    ].each { |file| @client.execute(File.read(Rails.root.join("db/clickhouse", file))) }
    @repository = HeartbeatRepository.new(client: @client)
    HeartbeatRepository.instance_variable_set(:@current, @repository)
  end

  teardown do
    @admin&.execute("DROP DATABASE IF EXISTS #{@database}") if @database
    ClickHouse::Client.instance_variable_set(:@current, @previous_client)
    ENV["CLICKHOUSE_TEST"] = @previous_test_setting
    HeartbeatRepository.instance_variable_set(:@current, @previous_repository)
  end

  test "ClickHouse readers retain PostgreSQL semantics across boundaries and mutations" do
    ENV["CLICKHOUSE_TEST"] = "0"
    user = User.create!(timezone: "America/New_York")
    base = Time.utc(2026, 3, 8, 6, 59, 30).to_f + 0.123456
    attributes = [
      [ 0, "alpha", "Ruby", "coding" ],
      [ 30, "alpha", "Ruby", "coding" ],
      [ 60, "beta", "Python", "coding" ],
      [ 90, "", nil, "coding" ],
      [ 250, nil, "Ruby", "browsing" ],
      [ 250, "beta", "Python", "coding" ],
      [ 310, "alpha", "Ruby", "coding" ]
    ].map.with_index do |(offset, project, language, category), index|
      Heartbeat.postgresql_unscoped.create!(
        user_id: user.id,
        time: base + offset,
        project:,
        language:,
        category:,
        entity: "src/file_#{index}.rb",
        editor: index.even? ? "vscode" : "neovim",
        source_type: :test_entry
      )
    end
    @repository.backfill(attributes)

    assert_parity(user, base)

    attributes.fetch(2).update!(deleted_at: Time.current)
    ENV["CLICKHOUSE_TEST"] = "1"
    @repository.change_deleted(heartbeat_id: attributes.fetch(2).id, user_id: user.id, deleted: true)
    assert_parity(user, base)

    ENV["CLICKHOUSE_TEST"] = "0"
    attributes.fetch(2).update!(deleted_at: nil)
    ENV["CLICKHOUSE_TEST"] = "1"
    @repository.change_deleted(heartbeat_id: attributes.fetch(2).id, user_id: user.id, deleted: false)
    assert_parity(user, base)
  end

  test "query-layout verification rejects a missing canonical row" do
    ENV["CLICKHOUSE_TEST"] = "0"
    user = User.create!(timezone: "UTC")
    heartbeat = Heartbeat.postgresql_unscoped.create!(
      user_id: user.id,
      time: Time.utc(2026, 8, 12, 12).to_f,
      entity: "repair.rb",
      category: "coding",
      source_type: :test_entry
    )
    @repository.backfill([ heartbeat ])
    @client.execute("TRUNCATE TABLE heartbeats_by_time")
    @repository.define_singleton_method(:insert_select) { |*, **| nil }
    ClickHouse::Client.instance_variable_set(:@current, @client)
    Rails.application.load_tasks unless Rake::Task.task_defined?("clickhouse:repair_query_layouts")

    error = assert_raises(SystemExit) do
      capture_io { Rake::Task["clickhouse:repair_query_layouts"].tap(&:reenable).invoke }
    end

    assert_equal 1, error.status
  end

  private

  def assert_parity(user, base)
    ENV["CLICKHOUSE_TEST"] = "0"
    postgres = Heartbeat.postgresql_unscoped.where(user_id: user.id, deleted_at: nil)
    range_start = base + 30
    range_end = base + 250
    expected = {
      rows: postgres.order(:time, :id).pluck(:id, :time, :project, :language, :category),
      range: postgres.where(time: range_start...range_end).order(:time, :id).pluck(:id, :time),
      count: postgres.count,
      grouped_count: postgres.group(:project).count,
      duration: postgres.duration_seconds,
      grouped_duration: postgres.group(:project).duration_seconds,
      attributed_language: Heartbeat.attributed_durations_by(postgres, :language),
      daily: postgres.daily_durations(
        user_timezone: user.timezone,
        start_date: Time.at(base - 1).utc,
        end_date: Time.at(base + 311).utc
      ),
      spans: postgres.to_span
    }

    ENV["CLICKHOUSE_TEST"] = "1"
    clickhouse = @repository.for_user(user.id)
    actual = {
      rows: clickhouse.order(:time, :id).pluck(:id, :time, :project, :language, :category),
      range: clickhouse.where(time: range_start...range_end).order(:time, :id).pluck(:id, :time),
      count: clickhouse.count,
      grouped_count: clickhouse.group(:project).count,
      duration: clickhouse.duration_seconds,
      grouped_duration: clickhouse.group(:project).duration_seconds,
      attributed_language: @repository.attributed_durations(clickhouse, :language),
      daily: clickhouse.daily_durations(
        user_timezone: user.timezone,
        start_date: Time.at(base - 1).utc,
        end_date: Time.at(base + 311).utc
      ),
      spans: clickhouse.to_span
    }

    assert_equal expected, actual
  end
end
