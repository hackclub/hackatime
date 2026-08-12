require "test_helper"

class HeartbeatRepositoryIntegrationTest < ActiveSupport::TestCase
  class FailingMirrorClient
    def initialize(client, &failure)
      @client = client
      @failure = failure
      @failed = false
    end

    def execute(sql, **)
      unless @failed || !@failure.call(sql)
        @failed = true
        raise ClickHouse::Client::Error, "mirror unavailable"
      end
      @client.execute(sql)
    end

    def insert_json_each_row(table, rows, settings: {})
      unless @failed || !@failure.call("INSERT INTO #{table}", rows)
        @failed = true
        raise ClickHouse::Client::Error, "mirror unavailable"
      end
      @client.insert_json_each_row(table, rows, settings:)
    end

    def method_missing(name, *arguments, **keywords, &block)
      @client.public_send(name, *arguments, **keywords, &block)
    end

    def respond_to_missing?(name, include_private = false)
      @client.respond_to?(name, include_private) || super
    end
  end

  test "ClickHouse preserves exact reads, deletion and retryable transfer semantics" do
    previous_repository = HeartbeatRepository.instance_variable_get(:@current)
    previous_test_setting = ENV["CLICKHOUSE_TEST"]
    require_clickhouse_integration!

    database = "hackatime_test_#{Process.pid}"
    admin = ClickHouse::Client.current
    admin.execute("DROP DATABASE IF EXISTS #{database}")
    admin.execute("CREATE DATABASE #{database}")
    client = ClickHouse::Client.new(ENV.fetch("CLICKHOUSE_URL").sub(%r{/[^/]+\z}, "/#{database}"))
    client.execute(File.read(Rails.root.join("db/clickhouse/001_create_heartbeats.sql")))
    client.execute(File.read(Rails.root.join("db/clickhouse/009_create_heartbeats_by_time.sql")))
    client.execute(File.read(Rails.root.join("db/clickhouse/012_create_heartbeat_store.sql")))
    client.execute(File.read(Rails.root.join("db/clickhouse/013_create_heartbeat_aliases.sql")))

    repository = HeartbeatRepository.new(client:)
    HeartbeatRepository.instance_variable_set(:@current, repository)
    ENV["CLICKHOUSE_TEST"] = "1"

    retry_row = {
      "user_id" => 1,
      "fields_hash" => "a" * 32,
      "heartbeat_id" => 1,
      "active" => true,
      "alias_version" => 1,
      "updated_at" => Time.current
    }
    2.times { repository.send(:insert_rows, "heartbeat_aliases", [ retry_row ]) }
    assert_equal 1, client.select("SELECT count() AS count FROM heartbeat_aliases WHERE user_id = 1").sole.fetch("count").to_i

    source = User.create!(id: 4_294_967_500, timezone: "UTC")
    target = User.create!(id: 4_294_967_501, timezone: "UTC")
    started_at = Time.current.beginning_of_day.to_f + 3_600.4097862
    result = HeartbeatIngest.call(
      user: source,
      mode: :direct,
      heartbeats: [
        {
          entity: "first.rb",
          project: "migration",
          time: started_at,
          type: "file",
          ysws_program: 7,
          dependencies: [ [ "rails" ], [ "redis", nil ] ]
        },
        { entity: "second.rb", project: "migration", time: started_at + 30.375, type: "file" },
        { entity: "third.rb", project: "migration", time: started_at + 300, type: "file" }
      ],
      request_context: { ip_address: "203.0.113.10" },
      schedule_rollup_refresh: false
    )

    assert_equal 3, result.persisted_count
    first_response = result.items.first.heartbeat
    assert_equal Heartbeat.generate_fields_hash(first_response.attributes), first_response.fields_hash
    original_timestamps = repository.for_user(source.id).order(:id).pluck(:id, :created_at, :updated_at)
    assert_equal 3, repository.for_user(source.id).count
    assert_equal [ started_at, started_at + 30.375, started_at + 300 ],
      repository.for_user(source.id).order(:id).pluck(:time)
    created_at, source_type, ip_address, lineno = repository.for_user(source.id).order(:id)
      .pick(:created_at, :source_type, :ip_address, :lineno)
    assert_instance_of ActiveSupport::TimeWithZone, created_at
    assert_equal "direct_entry", source_type
    assert_equal 7, repository.for_user(source.id).order(:id).first.ysws_program
    assert_instance_of IPAddr, ip_address
    assert_nil lineno
    assert_equal({ recent_count: 3, recent_imported_count: 0 }, Cache::HeartbeatCountsJob.new.send(:calculate))
    assert_equal [ [ "rails" ], [ "redis", nil ] ], repository.for_user(source.id).order(:id).first.dependencies
    assert_equal 3, client.select("SELECT count() AS count FROM heartbeats_by_time FINAL").first.fetch("count").to_i
    stored_fractional = client.select(<<~SQL.squish).sole
      SELECT #{HeartbeatRepository::STORE_COLUMNS.join(', ')} FROM heartbeat_store FINAL
      WHERE user_id = #{source.id} AND id = #{first_response.id}
    SQL
    assert_equal stored_fractional.fetch("payload_hash"), repository.send(:payload_hash, stored_fractional)
    assert_equal 150, repository.for_user(source.id).duration_seconds
    assert_equal 150, repository.boundary_aware_duration(
      repository.for_user(source.id),
      Time.zone.at(started_at + 30.375),
      started_at + 300
    )
    assert_equal 2, repository.for_user(source.id).where(time: started_at...(started_at + 31)).count
    assert_equal "203.0.113.10", repository.for_user(source.id).order(:id).first.ip_address.to_s
    assert_equal({ "migration" => 150 }, repository.for_user(source.id).group(:project).duration_seconds)
    assert_equal 3, repository.for_user(source.id).group(:project, :language).count.values.sum
    assert_equal({ project: [ "migration" ], category: [ "coding" ] },
      repository.filter_options(repository.for_user(source.id), %i[project category]))
    home_user = User.create!(timezone: "UTC")
    home_result = HeartbeatIngest.call(
      user: home_user,
      mode: :direct,
      heartbeats: [
        { entity: "archived.rb", project: "archived", time: started_at - 3_700, type: "file" },
        { entity: "included-1.rb", project: "included", time: started_at - 3_600, type: "file" },
        { entity: "included-2.rb", project: "included", time: started_at - 3_540, type: "file" }
      ],
      schedule_rollup_refresh: false
    )
    assert_equal 3, home_result.persisted_count
    archived_projects = [ [ source.id, "migration" ], [ home_user.id, "archived" ] ] +
      39_998.times.map { |index| [ source.id, "archived-#{index}" ] }
    assert_equal({ users_tracked: 1, seconds_tracked: 60 },
      repository.home_stats(archived_projects:))
    assert_equal 150, repository.today_stats(repository.for_user(source.id), timezone: "UTC")
      .fetch(:todays_duration_seconds)
    assert_equal 150, repository.daily_durations(
      repository.for_user(source.id),
      timezone: "America/New_York",
      start_time: started_at - 1,
      end_time: started_at + 301
    ).sum(&:last)
    since = Time.zone.at(started_at - 1)
    before = Time.zone.at(started_at + 301)
    assert_equal source.id, repository.latest_direct_heartbeats(since:).sole.fetch("user_id").to_i
    assert_equal 1, repository.active_users_by_hour(since:, before:).sole.fetch(:count)
    assert_empty repository.ip_machine_pairs(since:, limit: 100)
    assert_empty repository.shared_machines(since:, limit: 100)
    assert_includes client.select("SHOW CREATE TABLE heartbeats").first.fetch("statement"),
      "PRIMARY KEY (user_id, time_5m, time_second)"
    assert_not_includes client.select("SHOW CREATE TABLE heartbeats").first.fetch("statement"), "fields_hash"

    result.items.first.heartbeat.soft_delete
    assert_equal 2, repository.for_user(source.id).count
    assert_equal 1, repository.for_user(source.id).only_deleted.count
    assert_equal original_timestamps,
      repository.for_user(source.id).with_deleted.order(:id).pluck(:id, :created_at, :updated_at)
    duplicate = HeartbeatIngest.call(
      user: source,
      mode: :direct,
      heartbeats: [ {
        entity: "first.rb",
        project: "migration",
        time: started_at,
        type: "file",
        ysws_program: 7,
        dependencies: [ [ "rails" ], [ "redis", nil ] ]
      } ],
      request_context: { ip_address: "203.0.113.10" },
      schedule_rollup_refresh: false
    )
    assert_equal 0, duplicate.persisted_count
    assert_equal 1, duplicate.duplicate_count
    assert_equal 2, repository.for_user(source.id).count

    transfer = ActiveRecord::Base.transaction do
      repository.prepare_transfer(from_user_id: source.id, to_user_id: target.id)
    end
    2.times { repository.transfer_rows(transfer.reload) }
    transfer.update!(status: :completed, completed_at: Time.current)

    assert_equal 0, repository.for_user(source.id).count
    assert_equal 3, repository.for_user(source.id).with_deleted.count
    assert_equal 2, repository.for_user(target.id).count
    assert_equal 3, repository.for_user(target.id).with_deleted.count
    assert_equal [ target.id ], repository.all.where(time: (started_at - 1)..(started_at + 301)).distinct.pluck(:user_id)

    deleted = repository.for_user(target.id).only_deleted.first
    deleted.restore
    assert_equal 3, repository.for_user(target.id).count
    assert_equal original_timestamps,
      repository.for_user(target.id).order(:id).pluck(:id, :created_at, :updated_at)

    deletion_user = User.create!(timezone: "UTC")
    HeartbeatIngest.call(
      user: deletion_user,
      mode: :direct,
      heartbeats: [ { entity: "delete.rb", time: started_at, type: "file" } ],
      schedule_rollup_refresh: false
    )
    deletion = HeartbeatDeletion.create!(user_id: deletion_user.id)
    failed_deletion_repository = HeartbeatRepository.new(client: FailingMirrorClient.new(client) do |sql, _rows|
      sql.include?("INSERT INTO heartbeats_by_time")
    end)
    assert_raises(ClickHouse::Client::Error) do
      failed_deletion_repository.soft_delete_user(
        deletion_user.id,
        version: deletion.clickhouse_version,
        deleted_at: deletion.created_at
      )
    end
    assert_equal 0, client.select("SELECT count() count FROM heartbeats FINAL WHERE user_id=#{deletion_user.id} AND deleted_at IS NULL").first.fetch("count").to_i
    assert_equal 1, client.select("SELECT count() count FROM heartbeats_by_time FINAL WHERE user_id=#{deletion_user.id} AND deleted_at IS NULL").first.fetch("count").to_i
    repository.soft_delete_user(
      deletion_user.id,
      version: deletion.clickhouse_version,
      deleted_at: deletion.created_at
    )
    assert_equal 0, client.select("SELECT count() count FROM heartbeats_by_time FINAL WHERE user_id=#{deletion_user.id} AND deleted_at IS NULL").first.fetch("count").to_i

    transfer_source = User.create!(timezone: "UTC")
    transfer_target = User.create!(timezone: "UTC")
    HeartbeatIngest.call(
      user: transfer_source,
      mode: :direct,
      heartbeats: [ { entity: "transfer.rb", time: started_at, type: "file" } ],
      schedule_rollup_refresh: false
    )
    interrupted_transfer = ActiveRecord::Base.transaction do
      repository.prepare_transfer(from_user_id: transfer_source.id, to_user_id: transfer_target.id)
    end
    failed_transfer_repository = HeartbeatRepository.new(client: FailingMirrorClient.new(client) do |sql, _rows|
      sql.include?("INSERT INTO heartbeat_store")
    end)
    assert_raises(ClickHouse::Client::Error) do
      failed_transfer_repository.transfer_rows(interrupted_transfer)
    end
    repository.transfer_rows(interrupted_transfer.reload)
    interrupted_transfer.update!(status: :completed, completed_at: Time.current)
    %w[heartbeats heartbeats_by_time].each do |table|
      assert_equal 0, client.select("SELECT count() count FROM #{table} FINAL WHERE user_id=#{transfer_source.id} AND deleted_at IS NULL").first.fetch("count").to_i
      assert_equal 1, client.select("SELECT count() count FROM #{table} FINAL WHERE user_id=#{transfer_target.id} AND deleted_at IS NULL").first.fetch("count").to_i
    end
    transferred = repository.for_user(transfer_target.id).sole
    transferred.soft_delete.restore
    repository.transfer_rows(interrupted_transfer.reload)
    assert_equal 1, repository.for_user(transfer_target.id).count

    duplicate_source = User.create!(timezone: "UTC")
    duplicate_target = User.create!(timezone: "UTC")
    [ duplicate_source, duplicate_target ].each do |user|
      HeartbeatIngest.call(
        user:,
        mode: :direct,
        heartbeats: [ { entity: "same.rb", time: started_at, type: "file" } ],
        schedule_rollup_refresh: false
      )
    end
    duplicate_transfer = ActiveRecord::Base.transaction do
      repository.prepare_transfer(from_user_id: duplicate_source.id, to_user_id: duplicate_target.id)
    end
    repository.transfer_rows(duplicate_transfer)
    duplicate_transfer.update!(status: :completed, completed_at: Time.current)
    assert_equal 0, repository.for_user(duplicate_source.id).count
    assert_equal 1, repository.for_user(duplicate_target.id).count

    deleted_duplicate_source = User.create!(timezone: "UTC")
    deleted_duplicate_target = User.create!(timezone: "UTC")
    source_duplicate = HeartbeatIngest.call(
      user: deleted_duplicate_source,
      mode: :direct,
      heartbeats: [ { entity: "restore-on-transfer.rb", time: started_at, type: "file" } ],
      schedule_rollup_refresh: false
    )
    target_duplicate = HeartbeatIngest.call(
      user: deleted_duplicate_target,
      mode: :direct,
      heartbeats: [ { entity: "restore-on-transfer.rb", time: started_at, type: "file" } ],
      schedule_rollup_refresh: false
    )
    target_id = target_duplicate.items.sole.heartbeat.id
    target_duplicate.items.sole.heartbeat.soft_delete
    deleted_duplicate_transfer = ActiveRecord::Base.transaction do
      repository.prepare_transfer(
        from_user_id: deleted_duplicate_source.id,
        to_user_id: deleted_duplicate_target.id
      )
    end
    failed_duplicate_repository = HeartbeatRepository.new(client: FailingMirrorClient.new(client) do |sql, _rows|
      sql.include?("INSERT INTO heartbeats_by_time")
    end)
    assert_raises(ClickHouse::Client::Error) do
      failed_duplicate_repository.transfer_rows(deleted_duplicate_transfer)
    end
    repository.transfer_rows(deleted_duplicate_transfer.reload)
    deleted_duplicate_transfer.update!(status: :completed, completed_at: Time.current)
    assert_equal 0, repository.for_user(deleted_duplicate_source.id).count
    assert_equal target_id, repository.for_user(deleted_duplicate_target.id).sole.id
    assert_equal 1, source_duplicate.persisted_count

    ja4_user = User.create!(timezone: "UTC")
    ja4 = Ja4.create!(fingerprint: SecureRandom.hex(18))
    HeartbeatIngest.call(
      user: ja4_user,
      mode: :direct,
      heartbeats: [ { entity: "ja4.rb", time: started_at, type: "file" } ],
      request_context: { ja4: ja4.fingerprint },
      schedule_rollup_refresh: false
    )
    failed_ja4_repository = HeartbeatRepository.new(client: FailingMirrorClient.new(client) do |sql, _rows|
      sql.include?("INSERT INTO heartbeats_by_time")
    end)
    nullification = HeartbeatJa4Nullification.create!(ja4_id: ja4.id)
    assert_raises(ClickHouse::Client::Error) do
      failed_ja4_repository.nullify_ja4(ja4.id, version: nullification.clickhouse_version)
    end
    repository.nullify_ja4(ja4.id, version: nullification.clickhouse_version)
    %w[heartbeats heartbeats_by_time].each do |table|
      assert_equal 0, client.select("SELECT count() count FROM #{table} FINAL WHERE user_id=#{ja4_user.id} AND ja4_id IS NOT NULL").first.fetch("count").to_i
    end
    nullification.update!(completed_at: Time.current)
    late_ja4_attributes = HeartbeatRow.from_input({
      user_id: ja4_user.id,
      time: started_at + 60,
      entity: "late-ja4.rb",
      type: "file",
      category: "coding",
      source_type: :direct_entry,
      ja4_id: ja4.id,
      created_at: Time.current,
      updated_at: Time.current
    }).attributes
    late_ja4_record = repository.serialize_attributes(late_ja4_attributes).merge(
      "fields_hash" => repository.canonical_fields_hash(late_ja4_attributes),
      "alias_hashes" => [ Heartbeat.generate_fields_hash(late_ja4_attributes) ]
    )
    repository.send(:insert_store_rows, [ repository.send(:build_store_row, late_ja4_record) ])
    repository.reconcile_store
    assert_equal 2, repository.for_user(ja4_user.id).count
    assert_equal 0, repository.for_user(ja4_user.id).where.not(ja4_id: nil).count

    mutation_user = User.create!(timezone: "UTC")
    mutation_ja4 = Ja4.create!(fingerprint: SecureRandom.hex(18))
    mutation_result = HeartbeatIngest.call(
      user: mutation_user,
      mode: :direct,
      heartbeats: [ { entity: "mutation-ja4.rb", time: started_at, type: "file" } ],
      request_context: { ja4: mutation_ja4.fingerprint },
      schedule_rollup_refresh: false
    )
    mutation_nullification = HeartbeatJa4Nullification.create!(ja4_id: mutation_ja4.id)
    mutation_result.items.sole.heartbeat.soft_delete.restore
    assert_nil repository.for_user(mutation_user.id).sole.ja4_id
    mutation_nullification.update!(completed_at: Time.current)

    transfer_ja4_source = User.create!(timezone: "UTC")
    transfer_ja4_target = User.create!(timezone: "UTC")
    transfer_ja4 = Ja4.create!(fingerprint: SecureRandom.hex(18))
    HeartbeatIngest.call(
      user: transfer_ja4_source,
      mode: :direct,
      heartbeats: [ { entity: "transfer-ja4.rb", time: started_at, type: "file" } ],
      request_context: { ja4: transfer_ja4.fingerprint },
      schedule_rollup_refresh: false
    )
    transfer_with_nullification = ActiveRecord::Base.transaction do
      repository.prepare_transfer(from_user_id: transfer_ja4_source.id, to_user_id: transfer_ja4_target.id)
    end
    transfer_nullification = HeartbeatJa4Nullification.create!(ja4_id: transfer_ja4.id)
    2.times { repository.transfer_rows(transfer_with_nullification.reload) }
    assert_equal 0, repository.for_user(transfer_ja4_source.id).with_deleted.where.not(ja4_id: nil).count
    assert_equal 0, repository.for_user(transfer_ja4_target.id).with_deleted.where.not(ja4_id: nil).count
    transfer_with_nullification.update!(status: :completed, completed_at: Time.current)
    transfer_nullification.update!(completed_at: Time.current)

    missing_alias_user = User.create!(timezone: "UTC")
    failing_alias_repository = HeartbeatRepository.new(client: FailingMirrorClient.new(client) do |sql, _rows|
      sql.include?("INSERT INTO heartbeat_aliases")
    end)
    HeartbeatRepository.instance_variable_set(:@current, failing_alias_repository)
    interrupted = HeartbeatIngest.call(
      user: missing_alias_user,
      mode: :direct,
      heartbeats: [ { entity: "missing-alias.rb", time: started_at, type: "file" } ],
      schedule_rollup_refresh: false
    )
    assert_equal 1, interrupted.failed_count
    assert_equal 0, client.select(<<~SQL.squish).first.fetch("count").to_i
      SELECT count() AS count FROM heartbeat_aliases FINAL WHERE user_id = #{missing_alias_user.id}
    SQL
    retried = HeartbeatIngest.call(
      user: missing_alias_user,
      mode: :direct,
      heartbeats: [ { entity: "missing-alias.rb", time: started_at, type: "file" } ],
      schedule_rollup_refresh: false
    )
    assert_equal 1, retried.persisted_count
    HeartbeatRepository.instance_variable_set(:@current, repository)
    repository.reconcile_store
    assert_equal 2, client.select(<<~SQL.squish).first.fetch("count").to_i
      SELECT count() AS count FROM heartbeat_aliases FINAL WHERE user_id = #{missing_alias_user.id} AND active
    SQL
    assert_equal 1, repository.for_user(missing_alias_user.id).count

    stale_user = User.create!(timezone: "UTC")
    stale_result = HeartbeatIngest.call(
      user: stale_user,
      mode: :direct,
      heartbeats: [ { entity: "stale.rb", time: started_at, type: "file" } ],
      schedule_rollup_refresh: false
    )
    stale_version = repository.next_version
    stale_result.items.sole.heartbeat.soft_delete.restore
    assert_raises(RuntimeError) do
      repository.soft_delete_user(stale_user.id, version: stale_version, deleted_at: Time.current)
    end
    assert_equal 1, repository.for_user(stale_user.id).count

    late_source = User.create!(timezone: "UTC")
    late_target = User.create!(timezone: "UTC")
    timestamp = Time.current
    late_attributes = HeartbeatRow.from_input({
      user_id: late_source.id,
      time: started_at,
      entity: "late-transfer.rb",
      type: "file",
      category: "coding",
      source_type: :direct_entry,
      created_at: timestamp,
      updated_at: timestamp
    }).attributes
    candidate = repository.send(
      :build_store_row,
      repository.serialize_attributes(late_attributes).merge(
        "fields_hash" => repository.canonical_fields_hash(late_attributes),
        "alias_hashes" => [ Heartbeat.generate_fields_hash(late_attributes) ]
      )
    )
    late_transfer = ActiveRecord::Base.transaction do
      repository.prepare_transfer(from_user_id: late_source.id, to_user_id: late_target.id)
    end
    repository.transfer_rows(late_transfer)
    late_transfer.update!(status: :completed, completed_at: Time.current)
    repository.send(:insert_store_rows, [ candidate ])
    repository.reconcile_store
    assert_equal 0, repository.for_user(late_source.id).count
    assert_equal 1, repository.for_user(late_target.id).count

    batch_user = User.create!(timezone: "UTC")
    batch_inputs = 100.times.map do |index|
      { entity: "batch-#{index}.rb", time: started_at + 1_000 + index, type: "file" }
    end
    batch_inputs << batch_inputs.first.dup
    batch_result = HeartbeatIngest.call(
      user: batch_user,
      mode: :direct,
      heartbeats: batch_inputs,
      schedule_rollup_refresh: false
    )
    assert_equal 100, batch_result.persisted_count
    assert_equal 1, batch_result.duplicate_count
    assert_equal batch_inputs.pluck(:entity), batch_result.items.map { |item| item.heartbeat.entity }
    store_rows = client.select(<<~SQL.squish)
      SELECT id, version, store_version FROM heartbeat_store FINAL
      WHERE user_id = #{batch_user.id} AND canonicalized = true AND duplicate_of IS NULL
      ORDER BY id
    SQL
    assert_equal 100, store_rows.length
    assert_equal 1, store_rows.pluck("version").uniq.length
    assert_equal 1, store_rows.pluck("store_version").uniq.length
    aliases = client.select(<<~SQL.squish)
      SELECT fields_hash, heartbeat_id FROM heartbeat_aliases FINAL
      WHERE user_id = #{batch_user.id} AND active
    SQL
    assert_equal 200, aliases.length
    assert_empty aliases.pluck("heartbeat_id").map(&:to_i) - store_rows.pluck("id").map(&:to_i)
    assert_equal store_rows.pluck("id").map(&:to_i),
      client.select("SELECT id FROM heartbeats FINAL WHERE user_id = #{batch_user.id} ORDER BY id").pluck("id").map(&:to_i)
    assert_equal store_rows.pluck("id").map(&:to_i),
      client.select("SELECT id FROM heartbeats_by_time FINAL WHERE user_id = #{batch_user.id} ORDER BY id").pluck("id").map(&:to_i)
    assert_equal 0, Heartbeat.postgresql_unscoped.where(user_id: batch_user.id).count

    rejected = HeartbeatIngest.call(
      user: source,
      mode: :direct,
      heartbeats: [ { entity: "late.rb", time: started_at + 600, type: "file" } ],
      schedule_rollup_refresh: false
    )
    assert_equal 1, rejected.failed_count

    no_postgres_user = User.create!(timezone: "UTC")
    postgres = ActiveRecord::Base.connection
    postgres.rename_table(:heartbeats, :legacy_heartbeats_for_test)
    begin
      no_postgres_result = HeartbeatIngest.call(
        user: no_postgres_user,
        mode: :direct,
        heartbeats: [ { entity: "clickhouse-only.rb", time: started_at + 2_000, type: "file" } ],
        schedule_rollup_refresh: false
      )
      assert_equal 1, no_postgres_result.persisted_count
      heartbeat = repository.for_user(no_postgres_user.id).sole
      heartbeat.soft_delete.restore
      assert_equal "clickhouse-only.rb", repository.for_user(no_postgres_user.id).sole.entity
    ensure
      postgres.rename_table(:legacy_heartbeats_for_test, :heartbeats) if postgres.table_exists?(:legacy_heartbeats_for_test)
    end
  ensure
    ENV["CLICKHOUSE_TEST"] = previous_test_setting
    HeartbeatRepository.instance_variable_set(:@current, previous_repository)
    admin&.execute("DROP DATABASE IF EXISTS #{database}") if database
  end
end
