require "test_helper"

class HeartbeatRepositoryTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :inserts, :queries

    def initialize(results = [])
      @results = results
      @inserts = []
      @queries = []
    end

    def select(sql)
      @queries << sql
      @results.shift || []
    end

    def each_json_each_row(sql)
      return enum_for(__method__, sql) unless block_given?

      @queries << sql
      (@results.shift || []).each { |row| yield row }
    end

    def execute(sql)
      @queries << sql
    end

    def insert_json_each_row(table, rows, settings: {})
      @inserts << [ table, rows, settings ]
    end
  end

  class FailingClient < FakeClient
    def insert_json_each_row(*)
      raise ClickHouse::Client::Error, "temporarily unavailable"
    end
  end

  class FlakyInsertClient < FakeClient
    attr_reader :attempted_settings

    def initialize
      super
      @attempted_settings = []
    end

    def insert_json_each_row(table, rows, settings: {})
      @attempted_settings << settings
      raise ClickHouse::Client::Error, "TIMEOUT_EXCEEDED" if @attempted_settings.one?

      super
    end
  end

  class TimeoutBoundClient < FakeClient
    attr_reader :attempts, :timeouts

    def initialize
      super
      @attempts = 0
    end

    def with_timeouts(**timeouts)
      @timeouts = timeouts
      yield
    end

    def insert_json_each_row(*)
      @attempts += 1
      raise Timeout::Error, "timed out"
    end
  end

  class NoClickHouseRequestClient < FakeClient
    def select(*) = raise("unexpected ClickHouse request")
  end

  class FailingExecuteClient < FakeClient
    def initialize(fail_on:)
      super()
      @fail_on = fail_on
    end

    def execute(sql)
      super
      raise ClickHouse::Client::Error, "temporarily unavailable" if queries.length == @fail_on
    end
  end

  test "PostgreSQL remains the default outside the test override" do
    previous = ENV.delete("HEARTBEAT_STORE")
    original_env = Rails.method(:env)
    Rails.define_singleton_method(:env) { ActiveSupport::StringInquirer.new("production") }

    assert_not HeartbeatRepository.clickhouse?
  ensure
    Rails.define_singleton_method(:env, original_env) if original_env
    ENV["HEARTBEAT_STORE"] = previous if previous
  end

  test "scope uses five-minute buckets before the full-precision timestamp" do
    repository = HeartbeatRepository.new(client: FakeClient.new)
    sql = repository.for_user(42).where(time: 1_700_000_000.125...1_700_000_001.875)
      .order(time: :asc, id: :asc).sql(select: %i[id time])

    assert_includes sql, "`user_id` = 42"
    assert_includes sql, "time_5m >= intDiv(toInt64(floor(1700000000.125)), 300) * 300"
    assert_includes sql, "time_5m <= intDiv(toInt64(floor(1700000001.875)), 300) * 300"
    assert_includes sql, "`time` >= 1700000000.125"
    assert_includes sql, "`time` < 1700000001.875"
    assert_includes sql, "ORDER BY `time` ASC, `id` ASC"
  end

  test "negative timestamp buckets match ClickHouse intDiv semantics" do
    repository = HeartbeatRepository.new(client: FakeClient.new)
    row = { "user_id" => 42, "id" => 7, "time" => -1.1, "version" => 3 }
    visible = [ row.slice("user_id", "id", "version") ]
    client = FakeClient.new([ visible, visible ])

    verification_repository = HeartbeatRepository.new(client:)
    verification_repository.send(:verify_visible_versions!, "heartbeats", [ row ])
    verification_repository.send(:verify_visible_versions!, "heartbeats_by_time", [ row ])

    assert_includes client.queries.first, "(42, 0, -2, -1.1, 7)"
    assert_includes client.queries.first, "(user_id, time_5m, time_second, time, id)"
    assert_includes client.queries.second, "(0, -2, 42, -1.1, 7)"
    assert_includes client.queries.second, "(time_5m, time_second, user_id, time, id)"
    assert_includes repository.all.where(time: -1.1).to_sql,
      "time_5m = intDiv(toInt64(floor(-1.1)), 300) * 300"
  end

  test "delivery verification accepts a newer concurrent visible version" do
    row = { "user_id" => 42, "id" => 7, "time" => 1_700_000_000.125, "version" => 3 }
    visible = row.slice("user_id", "id").merge("version" => 4)

    assert_nothing_raised do
      HeartbeatRepository.new(client: FakeClient.new([ [ visible ] ]))
        .send(:verify_visible_versions!, "heartbeats", [ row ])
    end
  end

  test "invalid numeric filters retain empty Active Record semantics" do
    repository = HeartbeatRepository.new(client: FakeClient.new)

    assert_includes repository.all.where(id: "not-a-number").to_sql, "WHERE deleted_at IS NULL AND 0"
    assert_includes repository.all.where(source_type: "not-a-source").to_sql, "WHERE deleted_at IS NULL AND 0"
    assert_includes repository.all.where(ja4_id: "not-a-number").to_sql, "WHERE deleted_at IS NULL AND 0"
    assert_includes repository.all.where(id: [ nil, "not-a-number" ]).to_sql, "(`id` IS NULL)"
    assert_includes repository.all.not(id: "not-a-number").to_sql, "WHERE deleted_at IS NULL AND 0"
    assert_includes repository.all.not(id: [ 42, "not-a-number" ]).to_sql, "WHERE deleted_at IS NULL AND 0"
    assert_includes repository.all.where(id: "42", source_type: "direct_entry").to_sql, "`id` = 42"
    assert_includes repository.all.where(id: "42", source_type: "direct_entry").to_sql, "`source_type` = 0"
  end

  test "global time ranges use the by-time table while user ranges use the base table" do
    repository = HeartbeatRepository.new(client: FakeClient.new)

    global_sql = repository.all.where(time: 1_700_000_000..1_700_003_600).to_sql
    user_sql = repository.for_user(42).where(time: 1_700_000_000..1_700_003_600).to_sql
    multi_user_sql = repository.all.where(user_id: [ 41, 42 ]).where(time: 1_700_000_000..1_700_003_600).to_sql

    assert_includes global_sql, "FROM heartbeats_by_time FINAL"
    assert_includes user_sql, "FROM heartbeats FINAL"
    assert_includes multi_user_sql, "FROM heartbeats_by_time FINAL"
    assert_includes repository.all.order(time: :desc).to_sql, "FROM heartbeats_by_time FINAL"
  end

  test "Rails time ranges generate numeric bucket predicates" do
    repository = HeartbeatRepository.new(client: FakeClient.new)
    sql = repository.for_user(42).where(time: 1.hour.ago..Time.current).to_sql

    assert_match(/time_5m >= intDiv\(toInt64\(floor\(\d+\.\d+\)\), 300\) \* 300/, sql)
    assert_no_match(/floor\('/, sql)
  end

  test "named day and custom ranges preserve PostgreSQL integer boundaries" do
    repository = HeartbeatRepository.new(client: FakeClient.new)

    Time.use_zone("America/New_York") do
      travel_to Time.zone.local(2026, 8, 12, 12) do
        today_sql = repository.for_user(42).today.to_sql
        custom_sql = repository.for_user(42).filter_by_time_range(:custom, "2026-08-11", "2026-08-12").to_sql

        assert_includes today_sql, "`time` >= #{Time.current.beginning_of_day.to_i}"
        assert_includes today_sql, "`time` <= #{Time.current.end_of_day.to_i}"
        assert_not_includes today_sql, Time.current.end_of_day.to_f.to_s
        assert_includes custom_sql, "`time` >= #{Time.zone.parse('2026-08-11').beginning_of_day.to_i}"
        assert_includes custom_sql, "`time` <= #{Time.zone.parse('2026-08-12').end_of_day.to_i}"

        recent_sql = repository.all.recent.to_sql
        assert_includes recent_sql, "time_5m >="
        assert_match(/`time` >= \d+/, recent_sql)
        assert_match(/time > \d+/, recent_sql)
      end
    end
  end

  test "normalized user stats match PostgreSQL mixed timestamp selection" do
    client = FakeClient.new([ [ {
      "total_heartbeats" => 2,
      "last_heartbeat_at" => 1_700_000_000_000.0,
      "languages_used" => 1,
      "projects_worked_on" => 1,
      "days_active" => 2
    } ], [ { "duration" => 120 } ] ])
    repository = HeartbeatRepository.new(client:)

    result = repository.normalized_user_stats(repository.for_user(42))

    assert_equal 1_700_000_000.0, result.fetch("last_heartbeat_at")
    assert_includes client.queries.first, "maxOrNull(time) AS last_heartbeat_at"
  end

  test "single nullable grouped keys remain scalar" do
    client = FakeClient.new([ [ { "project" => nil, "count" => 2 } ] ])

    result = HeartbeatRepository.new(client:).for_user(42).group(:project).count

    assert_equal({ nil => 2 }, result)
  end

  test "combined archived-project conditions preserve per-user table routing" do
    repository = HeartbeatRepository.new(client: FakeClient.new)
    heartbeats = repository.for_user(42)
    scope = heartbeats.where(project: nil).or(heartbeats.where.not(project: [ "archived" ]))

    assert_includes scope.where(time: 1.day.ago..Time.current).to_sql, "FROM heartbeats FINAL"
  end

  test "latest user reads try a recent bucket range before the exact all-time fallback" do
    row = { "id" => 1, "user_id" => 42, "time" => 1_700_000_000.125, "source_type" => 0 }
    client = FakeClient.new([ [], [ row ] ])
    repository = HeartbeatRepository.new(client:)

    heartbeat = repository.for_user(42).order(time: :desc, id: :desc).first

    assert_equal row.fetch("time"), heartbeat.time
    assert_equal 2, client.queries.length
    assert_includes client.queries.first, "time_5m >="
    assert_not_includes client.queries.second, "time_5m >="
  end

  test "latest user plucks use the same recent probe and exact fallback" do
    client = FakeClient.new([ [], [ { "time" => 1_700_000_000.125 } ] ])
    repository = HeartbeatRepository.new(client:)

    time = repository.for_user(42).order(time: :desc, id: :desc).pick(:time)

    assert_equal 1_700_000_000.125, time
    assert_equal 2, client.queries.length
    assert_includes client.queries.first, "time_5m >="
    assert_not_includes client.queries.second, "time_5m >="
  end

  test "distinct plucks keep their distinct projection" do
    client = FakeClient.new([ [ { "user_id" => 42 } ] ])
    repository = HeartbeatRepository.new(client:)

    assert_equal [ 42 ], repository.all.distinct.pluck(:user_id)
    assert_includes client.queries.sole, "SELECT DISTINCT `user_id`"
  end

  test "plucks apply PostgreSQL attribute types but leave expressions raw" do
    client = FakeClient.new([ [ {
      "created_at" => "2026-08-12 14:23:45.123456",
      "source_type" => 0,
      "ip_address" => "203.0.113.1",
      "is_write" => true,
      "lineno" => nil
    } ], [ { "created_at" => "2026-08-12 14:23:45.123456" } ], [ { "id_string" => "42" } ] ])
    repository = HeartbeatRepository.new(client:)

    values = repository.all.pluck(:created_at, :source_type, :ip_address, :is_write, :lineno).sole

    assert_instance_of ActiveSupport::TimeWithZone, values[0]
    assert_equal "2026-08-12T14:23:45.123Z", values[0].as_json
    assert_equal "direct_entry", values[1]
    assert_instance_of IPAddr, values[2]
    assert_equal "203.0.113.1", values[2].as_json
    assert_equal true, values[3]
    assert_nil values[4]
    assert_instance_of ActiveSupport::TimeWithZone, repository.all.pick(:created_at)
    assert_equal "42", repository.all.pick("toString(id) AS id_string")
  end

  test "scope quotes strings and translates source type enums" do
    repository = HeartbeatRepository.new(client: FakeClient.new)
    sql = repository.all.where(project: "project' OR 1=1", source_type: :direct_entry).to_sql

    assert_includes sql, "`project` = 'project\\' OR 1=1'"
    assert_includes sql, "`source_type` = 0"
  end

  test "user-agent substring filters use the text-index prewhere" do
    repository = HeartbeatRepository.new(client: FakeClient.new)

    sql = repository.all.where("user_agent ILIKE ?", "%vscode%").to_sql

    assert_includes sql, "PREWHERE user_agent ILIKE '%vscode%'"
    assert_includes sql, "WHERE deleted_at IS NULL"
  end

  test "recent machine searches prune the by-time table with five-minute buckets" do
    client = FakeClient.new([ [], [], [] ])
    repository = HeartbeatRepository.new(client:)
    since = Time.at(1_700_000_000.125).utc

    repository.ip_machine_pairs(since:, limit: 100)
    repository.shared_machines(since:, limit: 100)
    repository.ip_machine_pairs(since:, limit: 100, inclusive: true)

    client.queries.each do |sql|
      assert_includes sql, "FROM heartbeats_by_time FINAL"
      assert_includes sql, "time_5m >= intDiv(toInt64(floor(1700000000.125)), 300) * 300"
    end
    assert_includes client.queries[0], "time > 1700000000.125"
    assert_includes client.queries[1], "time > 1700000000.125"
    assert_includes client.queries[2], "time >= 1700000000.125"
  end

  test "null dependencies remain distinct from an empty dependency list" do
    serialized = HeartbeatRepository.new(client: FakeClient.new).serialize_attributes(
      "source_type" => "direct_entry",
      "dependencies" => nil
    )
    assert_equal [], serialized.fetch("dependencies")
    assert serialized.fetch("dependencies_is_null")

    multidimensional = HeartbeatRepository.new(client: FakeClient.new).serialize_attributes(
      "source_type" => "direct_entry",
      "dependencies" => [ [ "rails" ], [ "redis", nil ] ]
    )
    assert_equal [], multidimensional.fetch("dependencies")
    assert_equal '[["rails"],["redis",null]]', multidimensional.fetch("dependencies_json")

    row = {
      "id" => 1,
      "user_id" => 1,
      "time" => Time.current.to_f,
      "source_type" => 0,
      "dependencies" => [],
      "dependencies_is_null" => true
    }
    repository = HeartbeatRepository.new(client: FakeClient.new([ [ row ], [ row ] ]))

    assert_nil repository.all.first.dependencies
    assert_nil repository.all.pluck(:dependencies).sole
  end

  test "enumerating rows streams them from ClickHouse" do
    rows = [
      { "id" => 1, "user_id" => 1, "time" => 1.0, "dependencies" => [], "dependencies_is_null" => true },
      { "id" => 2, "user_id" => 1, "time" => 2.0, "dependencies" => [ "rails" ], "dependencies_is_null" => false },
      {
        "id" => 3,
        "user_id" => 1,
        "time" => 3.0,
        "dependencies" => [],
        "dependencies_is_null" => false,
        "dependencies_json" => '[["rails"], ["redis", null]]'
      }
    ]
    client = FakeClient.new([ rows ])
    repository = HeartbeatRepository.new(client:)

    dependencies = repository.for_user(1).select(:id, :dependencies).map(&:dependencies)

    assert_equal [ nil, [ "rails" ], [ [ "rails" ], [ "redis", nil ] ] ], dependencies
    assert_includes client.queries.sole,
      "SELECT `id`, `dependencies`, `dependencies_is_null`, `dependencies_json` FROM heartbeats FINAL"
  end

  test "aggregates clear inherited ordering" do
    client = FakeClient.new([ [ { "value" => 2 } ] ])

    assert_equal 2, HeartbeatRepository.new(client:).all.order(time: :desc).count
    assert_not_includes client.queries.sole, "ORDER BY"
  end

  test "fields hash is store control data rather than heartbeat storage data" do
    assert_not_includes HeartbeatRepository::STORAGE_COLUMNS, "fields_hash"
    assert_includes HeartbeatRepository::STORE_CONTROL_COLUMNS, "fields_hash"
    assert_not_includes HeartbeatRepository.new(client: FakeClient.new).all.to_sql, "fields_hash"
  end

  test "delivery recovery scopes failure retries to the affected user" do
    client = FakeClient.new([ [] ])

    HeartbeatRepository.new(client:).reconcile_store(user_id: 42)

    assert_includes client.queries.sole, "WHERE (user_id = 42) AND (canonicalized = false OR"
  end

  test "ClickHouse inserts use stable deduplication tokens" do
    client = FakeClient.new
    repository = HeartbeatRepository.new(client:)
    rows = [ { "user_id" => 42, "id" => 7, "time" => Time.utc(2026, 8, 12).to_f, "version" => 3 } ]

    2.times { repository.send(:insert_rows, "heartbeats", rows) }
    repository.send(:insert_rows, "heartbeats", [ rows.sole.merge("version" => 4) ])

    settings = client.inserts.map(&:last)
    assert settings.none? { |value| value.key?(:insert_quorum) || value.key?(:insert_quorum_parallel) }
    assert_equal settings[0][:insert_deduplication_token], settings[1][:insert_deduplication_token]
    assert_not_equal settings[1][:insert_deduplication_token], settings[2][:insert_deduplication_token]
  end

  test "partitioned inserts split months before applying the row limit" do
    client = FakeClient.new
    rows = 121.times.map do |index|
      {
        "user_id" => 42,
        "id" => index + 1,
        "time" => (Time.utc(2016, 1, 1) + index.months).to_f,
        "version" => 3
      }
    end

    HeartbeatRepository.new(client:).send(:insert_rows, "heartbeats", rows)

    assert_equal 121, client.inserts.length
    assert client.inserts.all? { |_table, batch, _settings| batch.one? }
    assert_equal 121, client.inserts.map { |insert| insert.last.fetch(:insert_deduplication_token) }.uniq.length
  end

  test "partitioned inserts keep ten-thousand-row chunks and stable tokens" do
    client = FakeClient.new
    rows = 10_001.times.map do |index|
      { "user_id" => 42, "id" => index + 1, "time" => 1_700_000_000.0, "version" => 3 }
    end
    repository = HeartbeatRepository.new(client:)

    2.times { repository.send(:insert_rows, "heartbeats", rows) }

    assert_equal [ 10_000, 1, 10_000, 1 ], client.inserts.map { |insert| insert.second.length }
    tokens = client.inserts.map { |insert| insert.last.fetch(:insert_deduplication_token) }
    assert_equal tokens.first(2), tokens.last(2)
    assert_not_equal tokens.first, tokens.second
  end

  test "latest IP lookups batch large user lists" do
    last_id = HeartbeatRepository::QUERY_BATCH_SIZE + 1
    ids = (1..last_id).to_a
    client = FakeClient.new([
      [ { "user_id" => 1, "latest_ip_address" => "203.0.113.1" } ],
      [ { "user_id" => last_id, "latest_ip_address" => "203.0.113.2" } ]
    ])

    result = HeartbeatRepository.new(client:).latest_ip_by_user(ids)

    assert_equal({ 1 => "203.0.113.1", last_id => "203.0.113.2" }, result)
    assert_equal 2, client.queries.length
    assert_includes client.queries.first, "1, 2, 3"
    assert_not_includes client.queries.first, last_id.to_s
    assert_includes client.queries.second, last_id.to_s
    assert client.queries.all? { |query| query.bytesize < 262_144 }
  end

  test "daily streak lookups batch users within each timezone" do
    last_id = HeartbeatRepository::QUERY_BATCH_SIZE + 1
    ids = (1..last_id).to_a
    users = ids.map { |id| [ id, "UTC" ] }
    client = FakeClient.new([ [], [] ])
    original_where = User.method(:where)
    User.define_singleton_method(:where) do |conditions|
      relation = Object.new
      relation.define_singleton_method(:pluck) { |*| users.select { |id, _timezone| conditions.fetch(:id).include?(id) } }
      relation
    end

    result = HeartbeatRepository.new(client:).daily_streaks(
      ids,
      start_date: 8.days.ago,
      exclude_browser_time: false
    )

    assert_equal 0, result.fetch(1)
    assert_equal 0, result.fetch(last_id)

    assert_equal 2, client.queries.length
    assert_includes client.queries.first, "`user_id` IN (1, 2, 3"
    assert_not_includes client.queries.first, last_id.to_s
    assert_includes client.queries.second, "`user_id` IN (#{last_id})"
    assert client.queries.all? { |query| query.bytesize < 262_144 }
  ensure
    User.define_singleton_method(:where, original_where) if original_where
  end

  test "ClickHouse insert failures retry with the same synchronous insert token" do
    client = FlakyInsertClient.new

    HeartbeatRepository.new(client:).send(
      :insert_rows,
      "heartbeats",
      [ { "user_id" => 42, "id" => 7, "time" => Time.utc(2026, 8, 12).to_f, "version" => 3 } ]
    )

    assert_equal 2, client.attempted_settings.length
    assert_equal 1, client.attempted_settings.pluck(:insert_deduplication_token).uniq.length
    assert client.attempted_settings.all? { |settings| settings[:async_insert] == 0 }
    assert client.attempted_settings.all? { |settings| settings[:wait_for_async_insert] == 1 }
  end

  test "mutations use a short ClickHouse timeout and two total insert attempts" do
    client = TimeoutBoundClient.new
    repository = HeartbeatRepository.new(client:)
    row = { "user_id" => 42, "id" => 7, "time" => Time.utc(2026, 8, 12).to_f, "version" => 3 }

    assert_raises(Timeout::Error) do
      repository.send(:with_mutation_timeouts) do
        repository.send(:insert_rows, "heartbeats", [ row ])
      end
    end

    assert_equal 2, client.attempts
    assert_equal({ open_timeout: 5, read_timeout: 5, write_timeout: 5 }, client.timeouts)
  end

  test "ingest bounds time holding PostgreSQL locks and does not retry inserts" do
    client = TimeoutBoundClient.new
    repository = HeartbeatRepository.new(client:)
    row = { "user_id" => 42, "id" => 7, "time" => Time.utc(2026, 8, 12).to_f, "version" => 3 }

    assert_raises(Timeout::Error) do
      repository.send(:with_clickhouse_timeouts, timeout: HeartbeatRepository::INGEST_TIMEOUT,
        retry_limit: HeartbeatRepository::INGEST_INSERT_RETRY_LIMIT) do
        repository.send(:insert_rows, "heartbeats", [ row ])
      end
    end

    assert_equal 1, client.attempts
    assert_equal({ open_timeout: 2, read_timeout: 2, write_timeout: 2 }, client.timeouts)
  end

  test "lifecycle admission records controls without calling ClickHouse inside the relational transaction" do
    repository = HeartbeatRepository.new(client: NoClickHouseRequestClient.new)
    source = User.create!(timezone: "UTC")
    target = User.create!(timezone: "UTC")
    deleted_user = User.create!(timezone: "UTC")

    transfer = ActiveRecord::Base.transaction do
      repository.prepare_transfer(from_user_id: source.id, to_user_id: target.id)
    end
    deletion = ActiveRecord::Base.transaction { repository.prepare_deletion(deleted_user.id) }

    assert_equal [ source.id, target.id ], [ transfer.from_user_id, transfer.to_user_id ]
    assert_equal deleted_user.id, deletion.user_id
  end

  test "delivery verification keeps tuple queries below the server query-size limit" do
    user_id = 4_294_967_500
    first_id = 1_700_000_000_000_000
    rows = (HeartbeatRepository::QUERY_BATCH_SIZE + 1).times.map do |index|
      {
        "user_id" => user_id,
        "id" => first_id + index,
        "time" => 1_700_000_000.125 + index,
        "version" => 3
      }
    end
    visible = rows.map { |row| row.slice("user_id", "id", "version") }
    client = FakeClient.new([ visible.first(HeartbeatRepository::QUERY_BATCH_SIZE), visible.last(1) ])

    HeartbeatRepository.new(client:).send(:verify_visible_versions!, "heartbeats", rows)

    assert_equal 2, client.queries.length
    assert client.queries.all? { |query| query.bytesize < 262_144 }
    assert client.queries.all? { |query| query.include?("(user_id, time_5m, time_second, time, id)") }
  end

  test "backfill identity lookup uses the canonical store primary key" do
    client = FakeClient.new([ [] ])
    repository = HeartbeatRepository.new(client:)

    assert_empty repository.send(:store_rows_by_keys, [ [ 42, 7 ], [ 43, 8 ] ])

    assert_includes client.queries.sole, "(user_id, id) IN ((42, 7), (43, 8))"
  end

  test "visualization selects line and cursor pixels independently" do
    time = Time.utc(2026, 8, 12, 12).to_f
    client = FakeClient.new([ [
      { "time" => time, "lineno" => 10, "cursorpos" => nil },
      { "time" => time + 0.01, "lineno" => 10, "cursorpos" => 20 }
    ], [] ])

    result = HeartbeatRepository.new(client:).visualization(
      user_id: 42, start_time: Time.at(time), end_time: Time.at(time + 1)
    )

    assert_equal [ nil, 20 ], result.fetch(:points_by_day).values.sole.pluck(:cursorpos)
  end

  test "shared machines preserves frequency while filtering missing users" do
    user = User.create!(timezone: "UTC")
    client = FakeClient.new([ [ {
      "machine" => "shared", "machine_frequency" => 3, "user_ids" => [ user.id, -1 ]
    } ] ])

    row = HeartbeatRepository.new(client:).shared_machines(since: 1.day.ago, limit: 10).sole

    assert_equal 3, row.fetch("machine_frequency")
    assert_equal [ user.id ], row.fetch("user_ids")
  end

  test "project details excludes whitespace-only languages" do
    client = FakeClient.new([ [] ])

    HeartbeatRepository.new(client:).project_details(HeartbeatRepository.new(client:).all)

    assert_includes client.queries.sole,
      "groupUniqArrayIf(language, language IS NOT NULL AND notEmpty(trimBoth(language)))"
  end

  test "home stats stay in ClickHouse and exclude archived user projects" do
    client = FakeClient.new([ [ { "users_tracked" => 2, "seconds_tracked" => 360 } ] ])

    result = HeartbeatRepository.new(client:).home_stats(
      archived_projects: [ [ 42, "archived" ], [ 43, "other" ] ]
    )

    assert_equal({ users_tracked: 2, seconds_tracked: 360 }, result)
    assert_includes client.queries.sole, "FROM heartbeats FINAL"
    assert_includes client.queries.sole,
      "(user_id, ifNull(project, '')) NOT IN ((42, 'archived'), (43, 'other'))"
  end

  test "self transfers are rejected before ClickHouse writes" do
    user = User.create!(timezone: "UTC")
    repository = HeartbeatRepository.new(client: FakeClient.new)

    assert_raises(ArgumentError) do
      repository.prepare_transfer(from_user_id: user.id, to_user_id: user.id)
    end
    assert_not HeartbeatTransfer.new(
      from_user_id: user.id,
      to_user_id: user.id,
      heartbeat_count: 0
    ).valid?
    assert_includes ActiveRecord::Base.connection.check_constraints(:heartbeat_transfers).map(&:name),
      "heartbeat_transfers_distinct_users"
  end

  test "the cutover write fence rejects lifecycle admission" do
    previous = ENV["HEARTBEAT_WRITES_STOPPED"]
    ENV["HEARTBEAT_WRITES_STOPPED"] = "1"
    repository = HeartbeatRepository.new(client: FakeClient.new)

    assert_raises(RuntimeError) { repository.prepare_transfer(from_user_id: 1, to_user_id: 2) }
    assert_raises(RuntimeError) { repository.prepare_deletion(1) }
    assert_raises(RuntimeError) { repository.prepare_ja4_nullification(1) }
    assert_raises(RuntimeError) { repository.change_deleted(heartbeat_id: 1, user_id: 1, deleted: true) }
  ensure
    ENV["HEARTBEAT_WRITES_STOPPED"] = previous
  end

  test "the online backfill fence blocks lifecycle admission and queued jobs" do
    previous = ENV["HEARTBEAT_MUTATIONS_STOPPED"]
    ENV["HEARTBEAT_MUTATIONS_STOPPED"] = "1"
    repository = HeartbeatRepository.new(client: FakeClient.new)

    assert_raises(RuntimeError) { repository.prepare_transfer(from_user_id: 1, to_user_id: 2) }
    assert_raises(RuntimeError) { repository.prepare_deletion(1) }
    assert_raises(RuntimeError) { repository.prepare_ja4_nullification(1) }
    assert_raises(RuntimeError) { repository.change_deleted(heartbeat_id: 1, user_id: 1, deleted: true) }
    assert_raises(RuntimeError) { HeartbeatTransferJob.new.perform }
    assert_raises(RuntimeError) { HeartbeatDeletionJob.new.perform }
    assert_raises(RuntimeError) { HeartbeatJa4NullificationJob.new.perform }
  ensure
    ENV["HEARTBEAT_MUTATIONS_STOPPED"] = previous
  end

  test "store identity lookups are bounded for large batches" do
    hashes = (HeartbeatRepository::QUERY_BATCH_SIZE + 1).times.map { |index| Digest::MD5.hexdigest(index.to_s) }
    client = FakeClient.new([ [], [] ])

    HeartbeatRepository.new(client:).send(:store_rows_for_aliases, 42, hashes)

    assert_equal 2, client.queries.length
    assert_includes client.queries.first, hashes.first
    assert_not_includes client.queries.first, hashes.last
    assert_includes client.queries.last, hashes.last
    assert client.queries.all? { |query| query.bytesize < 262_144 }
  end

  test "restoring an identity replaces an inactive alias but not an active alias" do
    fields_hash = Digest::MD5.hexdigest("identity")
    row = { "user_id" => 42, "id" => 7, "fields_hash" => fields_hash }
    inactive = {
      "user_id" => 42,
      "fields_hash" => fields_hash,
      "heartbeat_id" => 8,
      "active" => false
    }
    inactive_client = FakeClient.new([ [ inactive ] ])

    HeartbeatRepository.new(client: inactive_client).send(:write_aliases, row, active: true)

    inserted = inactive_client.inserts.sole.second.sole
    assert_equal 7, inserted.fetch("heartbeat_id")
    assert inserted.fetch("active")

    active_client = FakeClient.new([ [ inactive.merge("active" => true) ] ])
    assert_raises(ActiveRecord::RecordNotUnique) do
      HeartbeatRepository.new(client: active_client).send(:write_aliases, row, active: true)
    end
  end
end
