require "test_helper"

class HeartbeatIngestTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  class ImportBatchRepository
    attr_reader :batch_sizes

    def initialize
      @batch_sizes = []
    end

    def serialize_attributes(attributes) = attributes.stringify_keys

    def persist(user_id:, records:)
      @batch_sizes << records.length
      records.map { { inserted: true, row: { "user_id" => user_id } } }
    end
  end

  setup do
    Rails.cache.clear
    clear_enqueued_jobs
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
  end

  teardown do
    Rails.cache.clear
    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  test "direct heartbeat ingest persists normalized heartbeats and schedules dashboard rollup refresh" do
    user = User.create!(timezone: "UTC")

    assert_difference("user.heartbeats.count", 1) do
      assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ]) do
        assert_enqueued_with(job: AttemptProjectRepoMappingJob, args: [ user.id, "hackatime" ]) do
          result = HeartbeatIngest.call(
            user: user,
            mode: :direct,
            heartbeats: [ {
              entity: "src/main.rb",
              plugin: "vscode/1.0.0",
              project: "hackatime",
              time: Time.current.to_f,
              type: "file"
            } ],
            request_context: {
              ip_address: "203.0.113.10",
              machine: "laptop",
              ja4: "t13d1516h2_8daaf6152771_02713d6af862"
            }
          )

          assert_equal 1, result.total_count
          assert_equal 1, result.persisted_count
          assert_equal 0, result.duplicate_count
          assert_equal 0, result.failed_count
          assert_equal 1, result.items.length
          assert_equal :accepted, result.items.first.status
        end
      end
    end

    heartbeat = user.heartbeats.order(:id).last
    assert_equal "vscode/1.0.0", heartbeat.user_agent
    assert_equal "coding", heartbeat.category
    assert_equal "laptop", heartbeat.machine
    assert_equal "203.0.113.10", heartbeat.ip_address.to_s
    assert_equal "t13d1516h2_8daaf6152771_02713d6af862", heartbeat.ja4.fingerprint
    assert_equal "direct_entry", heartbeat.source_type
  end

  test "direct heartbeat ingest applies blank defaults and falls back to body metadata" do
    user = User.create!(timezone: "UTC")

    HeartbeatIngest.call(
      user: user,
      mode: :direct,
      heartbeats: [ {
        category: "",
        editor: "zed",
        entity: "src/main.rb",
        machine: "body-machine",
        operating_system: "linux",
        plugin: "zed/1.0.0",
        time: Time.current.to_f,
        type: "file",
        user_agent: ""
      } ]
    )

    heartbeat = user.heartbeats.sole
    assert_equal "coding", heartbeat.category
    assert_equal "zed/1.0.0", heartbeat.user_agent
    assert_equal "zed", heartbeat.editor
    assert_equal "linux", heartbeat.operating_system
    assert_equal "body-machine", heartbeat.machine
  end

  test "direct heartbeat ingest classifies uncategorized browser heartbeats as browsing" do
    user = User.create!(timezone: "UTC")

    HeartbeatIngest.call(
      user: user,
      mode: :direct,
      heartbeats: [ { entity: "example.com", time: Time.current.to_f, type: "domain" } ]
    )

    assert_equal "browsing", user.heartbeats.sole.category
  end

  test "direct heartbeat ingest classifies a minimal heartbeat as coding" do
    user = User.create!(timezone: "UTC")

    HeartbeatIngest.call(
      user: user,
      mode: :direct,
      heartbeats: [ { entity: "LICENSE", time: Time.current.to_f } ]
    )

    assert_equal "coding", user.heartbeats.sole.category
  end

  test "direct heartbeat ingest uses the HTTP user agent when the body omits it" do
    user = User.create!(timezone: "UTC")
    user_agent = "wakatime/v1.0.0 (linux-x86_64) go1.0.0 zed/1.0.0"

    HeartbeatIngest.call(
      user: user,
      mode: :direct,
      heartbeats: [ { entity: "src/main.rb", time: Time.current.to_f, type: "file" } ],
      request_context: { user_agent: user_agent }
    )

    heartbeat = user.heartbeats.sole
    assert_equal user_agent, heartbeat.user_agent
    assert_equal "zed", heartbeat.editor
  end

  test "direct heartbeat ingest prefers request machine over body machine" do
    user = User.create!(timezone: "UTC")

    HeartbeatIngest.call(
      user: user,
      mode: :direct,
      heartbeats: [ {
        entity: "src/main.rb",
        machine: "body-machine",
        time: Time.current.to_f,
        type: "file"
      } ],
      request_context: { machine: "header-machine" }
    )

    assert_equal "header-machine", user.heartbeats.sole.machine
  end

  test "direct heartbeat ingest reuses a JA4 record across requests" do
    user = User.create!(timezone: "UTC")
    ja4 = "t13d1516h2_8daaf6152771_02713d6af862"

    assert_difference({ "user.heartbeats.count" => 2, "Ja4.count" => 1 }) do
      HeartbeatIngest.call(
        user: user,
        mode: :direct,
        heartbeats: [ { entity: "src/first.rb", time: Time.current.to_f, type: "file" } ],
        request_context: { ja4: ja4 }
      )
      HeartbeatIngest.call(
        user: user,
        mode: :direct,
        heartbeats: [ { entity: "src/second.rb", time: 1.second.from_now.to_f, type: "file" } ],
        request_context: { ja4: ja4 }
      )
    end

    assert_equal [ ja4 ], user.heartbeats.joins(:ja4).distinct.pluck("ja4s.fingerprint")
  end

  test "direct heartbeat ingest returns existing heartbeat for duplicate input" do
    user = User.create!(timezone: "UTC")
    payload = {
      entity: "src/main.rb",
      plugin: "vscode/1.0.0",
      project: "hackatime",
      time: Time.current.to_f,
      type: "file"
    }

    first_result = HeartbeatIngest.call(
      user: user,
      mode: :direct,
      heartbeats: [ payload ],
      request_context: { ip_address: "203.0.113.10" }
    )
    first_heartbeat = first_result.items.first.heartbeat

    clear_enqueued_jobs

    assert_no_difference("user.heartbeats.count") do
      result = HeartbeatIngest.call(
        user: user,
        mode: :direct,
        heartbeats: [ payload ],
        request_context: { ip_address: "203.0.113.20" }
      )

      assert_equal 1, result.total_count
      assert_equal 0, result.persisted_count
      assert_equal 1, result.duplicate_count
      assert_equal 0, result.failed_count
      assert_equal first_heartbeat.id, result.items.first.heartbeat.id
    end

    assert_no_enqueued_jobs only: DashboardRollupRefreshJob
  end

  test "direct heartbeat ingest inserts distinct bulk items in one statement and preserves item order" do
    user = User.create!(timezone: "UTC")
    now = Time.current.to_f
    sql = []
    subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
      statement = payload[:sql]
      sql << statement if statement.include?('"heartbeats"') && !payload[:cached]
    end

    result = ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      HeartbeatIngest.call(
        user: user,
        mode: :direct,
        heartbeats: [
          { entity: "src/first.rb", project: "one", time: now - 1, type: "file" },
          { branch: "main", entity: "src/second.py", project: "two", time: now, type: "file" }
        ]
      )
    end

    assert_equal 2, result.persisted_count
    assert_equal 0, result.duplicate_count
    assert_equal [ "src/first.rb", "src/second.py" ], result.items.map { |item| item.heartbeat.entity }
    insert = sql.select { |statement| statement.start_with?('INSERT INTO "heartbeats"') }.sole
    assert_includes insert, "ON CONFLICT"
    assert_includes insert, "DO NOTHING"
    assert_equal 1, sql.count { |statement| statement.start_with?("SELECT") && statement.include?("fields_hash") }
  end

  test "direct heartbeat ingest runs model validations before bulk insertion" do
    user = User.create!(timezone: "UTC")
    validation = lambda do |heartbeat|
      heartbeat.errors.add(:entity, "is rejected by a model validation") if heartbeat.entity == "rejected.rb"
    end
    Heartbeat.set_callback(:validate, :before, validation)

    begin
      assert_no_difference("user.heartbeats.count") do
        result = HeartbeatIngest.call(
          user:,
          mode: :direct,
          heartbeats: [ { entity: "rejected.rb", time: Time.current.to_f, type: "file" } ]
        )

        assert_equal 1, result.failed_count
        assert_instance_of ActiveRecord::RecordInvalid, result.items.sole.error
        assert_includes result.items.sole.error.message, "Entity is rejected by a model validation"
      end
    ensure
      Heartbeat.skip_callback(:validate, :before, validation)
    end
  end

  test "import heartbeat ingest runs model validations before bulk insertion" do
    user = User.create!(timezone: "UTC")
    validation = lambda do |heartbeat|
      heartbeat.errors.add(:entity, "is rejected by a model validation") if heartbeat.entity == "rejected.rb"
    end
    Heartbeat.set_callback(:validate, :before, validation)

    begin
      assert_no_difference("user.heartbeats.count") do
        result = HeartbeatIngest.call(
          user:,
          mode: :import,
          heartbeats: [ { entity: "rejected.rb", time: Time.current.to_f, type: "file" } ]
        )

        assert_equal 1, result.failed_count
        assert_equal "ActiveRecord::RecordInvalid", result.errors.sole[:type]
        assert_includes result.errors.sole[:error], "Entity is rejected by a model validation"
      end
    ensure
      Heartbeat.skip_callback(:validate, :before, validation)
    end
  end

  test "a validation failure does not seed placeholder state for later bulk items" do
    user = User.create!(timezone: "UTC")
    now = Time.current.to_f
    validation = lambda do |heartbeat|
      heartbeat.errors.add(:entity, "is rejected by a model validation") if heartbeat.entity == "rejected.py"
    end
    Heartbeat.set_callback(:validate, :before, validation)

    begin
      result = HeartbeatIngest.call(
        user:,
        mode: :direct,
        heartbeats: [
          { entity: "rejected.py", language: "Python", project: "demo", time: now - 1, type: "file" },
          { entity: "accepted", language: "<<LAST_LANGUAGE>>", project: "demo", time: now, type: "file" }
        ]
      )

      assert_equal 1, result.persisted_count
      assert_equal 1, result.failed_count
      assert_nil user.heartbeats.sole.language
    ensure
      Heartbeat.skip_callback(:validate, :before, validation)
    end
  end

  test "direct heartbeat ingest refetches a concurrent winner after an insert conflict" do
    user = User.create!(timezone: "UTC")
    payload = { entity: "src/raced.rb", time: Time.current.to_f, type: "file" }
    winner = nil
    no_inserted_rows = ActiveRecord::Result.new([], [])
    original_insert_all = Heartbeat.method(:insert_all)

    Heartbeat.define_singleton_method(:insert_all) do |records, **|
      winner = Heartbeat.create!(records.sole)
      no_inserted_rows
    end

    begin
      result = HeartbeatIngest.call(user:, mode: :direct, heartbeats: [ payload ])

      assert_equal 0, result.persisted_count
      assert_equal 1, result.duplicate_count
      assert_equal 0, result.failed_count
      assert_equal winner.id, result.items.sole.heartbeat.id
    ensure
      Heartbeat.define_singleton_method(:insert_all, original_insert_all)
    end

    assert_equal 1, user.heartbeats.count
  end

  test "direct heartbeat ingest rebuilds partition attributes inside a schema retry" do
    user = User.create!(timezone: "UTC")
    time = Time.current.to_f
    attrs = { user_id: user.id, entity: "src/main.rb", time:, type: "file", category: "coding", source_type: :direct_entry }
    model_attributes = Heartbeat.new(attrs).attributes
    fields_hash = Heartbeat.generate_fields_hash(model_attributes)
    entry = { attrs:, model_attributes:, fields_hash: }
    ingest = HeartbeatIngest.new(user:, mode: :direct, heartbeats: [], schedule_rollup_refresh: false)
    attempts = []
    include_time_epoch = false
    original_column_names = Heartbeat.method(:column_names)
    original_insert_all = Heartbeat.method(:insert_all)

    Heartbeat.define_singleton_method(:column_names) do
      columns = original_column_names.call
      include_time_epoch ? columns + [ "time_epoch" ] : columns
    end
    Heartbeat.define_singleton_method(:insert_all) do |records, **|
      attempts << records
      raise ArgumentError, "stale schema" if attempts.one?

      ActiveRecord::Result.new([ "fields_hash" ], [ [ fields_hash ] ])
    end
    ingest.define_singleton_method(:with_heartbeat_unique_by) do |&block|
      block.call([ :fields_hash ])
    rescue ArgumentError
      include_time_epoch = true
      block.call(%i[fields_hash time_epoch])
    end

    begin
      ingest.send(:persist_direct_heartbeats, [ entry ])
    ensure
      Heartbeat.define_singleton_method(:column_names, original_column_names)
      Heartbeat.define_singleton_method(:insert_all, original_insert_all)
    end

    assert_not attempts.first.sole.key?("time_epoch")
    assert_equal time.floor, attempts.second.sole.fetch("time_epoch")
  end

  test "direct heartbeat ingest deduplicates repeated items within one bulk request" do
    user = User.create!(timezone: "UTC")
    payload = {
      entity: "src/main.rb",
      project: "hackatime",
      time: Time.current.to_f,
      type: "file"
    }

    assert_difference("user.heartbeats.count", 1) do
      result = HeartbeatIngest.call(
        user: user,
        mode: :direct,
        heartbeats: [ payload, payload.dup ]
      )

      assert_equal 2, result.total_count
      assert_equal 1, result.persisted_count
      assert_equal 1, result.duplicate_count
      assert_equal 0, result.failed_count
      assert_equal 1, result.items.map { |item| item.heartbeat.id }.uniq.length
    end
  end

  test "direct heartbeat ingest resolves last language within the batch" do
    user = User.create!(timezone: "UTC")
    now = Time.current.to_f

    result = HeartbeatIngest.call(
      user: user,
      mode: :direct,
      heartbeats: [
        {
          entity: "src/first.py",
          plugin: "vscode/1.0.0",
          project: "hackatime",
          time: now - 1,
          type: "file",
          language: "Python"
        },
        {
          entity: "src/second.rb",
          plugin: "vscode/1.0.0",
          project: "hackatime",
          time: now,
          type: "file",
          language: "<<LAST_LANGUAGE>>"
        }
      ]
    )

    assert_equal 2, result.persisted_count
    heartbeats = user.heartbeats.order(:time)
    assert_equal [ "Python", "Python" ], heartbeats.pluck(:language)
  end

  test "direct heartbeat ingest normalizes millisecond-scaled epoch times" do
    user = User.create!(timezone: "UTC")
    sane_time = Time.current.to_f

    HeartbeatIngest.call(
      user: user,
      mode: :direct,
      heartbeats: [ { entity: "src/main.rb", time: (sane_time * 1000).round, type: "file" } ]
    )

    assert_in_delta sane_time, user.heartbeats.sole.time, 1.0
  end

  test "direct AI heartbeat ingest stores the editor instead of the model" do
    user = User.create!(timezone: "UTC")

    HeartbeatIngest.call(
      user: user,
      mode: :direct,
      heartbeats: [ {
        category: "ai coding",
        entity: "Claude session",
        time: Time.current.to_f,
        type: "app",
        user_agent: "wakatime/v2.21.4 (darwin-25.5.0-arm64) go1.26.4 opus/4-8 claude-code/2.1.202"
      } ]
    )

    heartbeat = user.heartbeats.sole
    assert_equal "claude-code", heartbeat.editor
    assert_equal "opus/4-8", heartbeat.ai_model
    assert_equal "macos", heartbeat.operating_system
  end

  test "direct AI heartbeat ingest does not deduplicate distinct telemetry at the same timestamp" do
    user = User.create!(timezone: "UTC")
    timestamp = Time.current.to_f
    base = {
      ai_session: "session-123",
      category: "ai coding",
      entity: "Claude session",
      time: timestamp,
      type: "app",
      user_agent: "wakatime/v2.21.4 (darwin-arm64) go1.26.4 opus/4-8 claude-code/2.1.202"
    }

    result = HeartbeatIngest.call(
      user: user,
      mode: :direct,
      heartbeats: [ base.merge(ai_output_tokens: 100), base.merge(ai_output_tokens: 200) ]
    )

    assert_equal 2, result.persisted_count
    assert_equal [ 100, 200 ], user.heartbeats.order(:ai_output_tokens).pluck(:ai_output_tokens)
  end

  test "import heartbeat ingest normalizes nanosecond-scaled epoch times" do
    user = User.create!(timezone: "UTC")
    sane_time = 1_700_000_000.0

    HeartbeatIngest.call(
      user: user,
      mode: :import,
      heartbeats: [ { entity: "/tmp/test.rb", type: "file", time: sane_time * 1_000_000_000 } ]
    )

    assert_in_delta sane_time, user.heartbeats.sole.time, 1.0
  end

  test "import heartbeat ingest applies blank defaults and sanitizes project names" do
    user = User.create!(timezone: "UTC")

    HeartbeatIngest.call(
      user: user,
      mode: :import,
      heartbeats: [ {
        category: "",
        entity: "/tmp/test.rb",
        project: "  hacka\u0000time\n",
        time: 1_700_000_000.0,
        type: "file"
      } ]
    )

    heartbeat = user.heartbeats.sole
    assert_equal "coding", heartbeat.category
    assert_equal "hackatime", heartbeat.project
  end

  test "import heartbeat ingest recognizes a pre-normalization fields hash" do
    user = User.create!(timezone: "UTC")
    raw = {
      category: "",
      entity: "/tmp/test.rb",
      project: "  hackatime\n",
      time: 1_700_000_000.0,
      type: "file"
    }
    create_legacy_imported_heartbeat(
      user,
      category: raw[:category], entity: raw[:entity], language: "Ruby",
      project: raw[:project], time: raw[:time], type: raw[:type]
    )

    assert_no_difference("user.heartbeats.count") do
      result = HeartbeatIngest.call(user: user, mode: :import, heartbeats: [ raw ])

      assert_equal 0, result.persisted_count
      assert_equal 1, result.duplicate_count
    end
  end

  test "import heartbeat ingest recognizes legacy hashes containing placeholders" do
    user = User.create!(timezone: "UTC")
    raw = {
      branch: "<<LAST_BRANCH>>",
      entity: "/tmp/test.rb",
      language: "<<LAST_LANGUAGE>>",
      project: "api",
      time: 1_700_000_000.0,
      type: "file"
    }
    create_legacy_imported_heartbeat(user, raw.merge(category: "coding"))

    assert_no_difference("user.heartbeats.count") do
      result = HeartbeatIngest.call(user: user, mode: :import, heartbeats: [ raw ])

      assert_equal 0, result.persisted_count
      assert_equal 1, result.duplicate_count
    end
  end

  test "import heartbeat ingest recognizes legacy user agent normalization hashes" do
    user = User.create!(timezone: "UTC")
    user_agent = "wakatime/v1.0.0 (darwin-arm64) go1.0.0 vscode/1.90.0"
    raw = {
      category: "coding",
      entity: "/tmp/test.rb",
      project: "api",
      time: 1_700_000_000.0,
      type: "file",
      user_agent:
    }
    create_legacy_imported_heartbeat(
      user,
      raw.merge(editor: "vscode", language: "Ruby", operating_system: "darwin")
    )

    assert_no_difference("user.heartbeats.count") do
      result = HeartbeatIngest.call(user: user, mode: :import, heartbeats: [ raw ])

      assert_equal 0, result.persisted_count
      assert_equal 1, result.duplicate_count
    end
  end

  test "import heartbeat ingest preserves AI telemetry" do
    user = User.create!(timezone: "UTC")

    HeartbeatIngest.call(
      user: user,
      mode: :import,
      heartbeats: [ {
        ai_input_tokens: 1_000,
        ai_line_changes: 12,
        ai_output_tokens: 250,
        ai_prompt_length: 80,
        ai_session: "session-123",
        ai_subscription_plan: "pro",
        category: "ai coding",
        editor: "mythos",
        entity: "/tmp/test.rb",
        human_line_changes: 4,
        time: 1_700_000_000.0,
        type: "file",
        user_agent: "wakatime/v2.21.4 (linux-x86_64) go1.26.4 mythos/5-high opencode-cli/1.4.4"
      } ]
    )

    heartbeat = user.heartbeats.sole
    assert_equal "mythos/5-high", heartbeat.ai_model
    assert_equal "opencode-cli", heartbeat.editor
    assert_equal "session-123", heartbeat.ai_session
    assert_equal "pro", heartbeat.ai_subscription_plan
    assert_equal 1_000, heartbeat.ai_input_tokens
    assert_equal 250, heartbeat.ai_output_tokens
    assert_equal 80, heartbeat.ai_prompt_length
    assert_equal 12, heartbeat.ai_line_changes
    assert_equal 4, heartbeat.human_line_changes
  end

  test "direct heartbeat ingest does not queue repo mapping for the last-project sentinel" do
    user = User.create!(timezone: "UTC")

    assert_no_enqueued_jobs only: AttemptProjectRepoMappingJob do
      HeartbeatIngest.call(
        user: user,
        mode: :direct,
        heartbeats: [ {
          entity: "src/main.rb",
          project: "<<LAST_PROJECT>>",
          time: Time.current.to_f,
          type: "file"
        } ]
      )
    end
  end

  test "epoch normalization preserves sane values and rejects unrepairable values" do
    ingest = HeartbeatIngest.new(user: User.new, mode: :direct, heartbeats: [])

    sane = Time.current.to_f
    assert_equal sane, ingest.send(:normalize_epoch_time, sane)
    assert_raises(HeartbeatIngest::InvalidHeartbeatTime) { ingest.send(:normalize_epoch_time, 2026) }
    assert_raises(HeartbeatIngest::InvalidHeartbeatTime) { ingest.send(:normalize_epoch_time, -9_999_999) }
    assert_raises(HeartbeatIngest::InvalidHeartbeatTime) { ingest.send(:normalize_epoch_time, "not-a-time") }
    assert_raises(HeartbeatIngest::InvalidHeartbeatTime) { ingest.send(:normalize_epoch_time, Float::NAN) }
  end

  test "direct heartbeat ingest reports invalid timestamps without persisting them" do
    user = User.create!(timezone: "UTC")

    assert_no_difference("user.heartbeats.count") do
      result = HeartbeatIngest.call(
        user: user,
        mode: :direct,
        heartbeats: [ { entity: "src/main.rb", time: 2026, type: "file" } ]
      )

      assert_equal 1, result.failed_count
      assert_instance_of HeartbeatIngest::InvalidHeartbeatTime, result.items.sole.error
    end
  end

  test "direct heartbeat ingest strips null bytes from string attributes" do
    user = User.create!(timezone: "UTC")

    result = HeartbeatIngest.call(
      user: user,
      mode: :direct,
      heartbeats: [ {
        branch: "mai\0n",
        dependencies: [ "active\0support" ],
        entity: "src/mai\0n.rb",
        time: Time.current.to_f,
        type: "fi\0le"
      } ]
    )

    assert_equal 0, result.failed_count
    assert_equal 1, result.persisted_count
    heartbeat = user.heartbeats.sole
    assert_equal "main", heartbeat.branch
    assert_equal [ "activesupport" ], heartbeat.dependencies
    assert_equal "src/main.rb", heartbeat.entity
    assert_equal "file", heartbeat.type
  end

  test "direct placeholder resolution is scoped to the project and preserves last project" do
    user = User.create!(timezone: "UTC")
    now = Time.current.to_f

    HeartbeatIngest.call(
      user: user,
      mode: :direct,
      heartbeats: [
        { entity: "a.rb", project: "a", branch: "main", language: "Ruby", time: now - 3, type: "file" },
        { entity: "b.py", project: "b", branch: "trunk", language: "Python", time: now - 2, type: "file" },
        { entity: "b-next.py", project: "b", branch: "<<LAST_BRANCH>>", language: "<<LAST_LANGUAGE>>", time: now - 1, type: "file" },
        { entity: "last.py", project: "<<LAST_PROJECT>>", branch: "<<LAST_BRANCH>>", language: "<<LAST_LANGUAGE>>", time: now, type: "file" }
      ]
    )

    heartbeats = user.heartbeats.order(:time).last(2)
    assert_equal [ "Python", "Python" ], heartbeats.pluck(:language)
    assert_equal [ "trunk", "trunk" ], heartbeats.pluck(:branch)
    assert_equal "<<LAST_PROJECT>>", heartbeats.last.project
  end

  test "placeholder resolution fills missing in-batch context from database history" do
    user = User.create!(timezone: "UTC")
    now = Time.current.to_f
    user.heartbeats.create!(
      entity: "historical.rb", project: "api", branch: "main", language: "Ruby",
      category: "coding", source_type: :direct_entry, time: now - 10, type: "file"
    )

    HeartbeatIngest.call(
      user: user,
      mode: :direct,
      heartbeats: [
        { entity: "first.py", project: "api", language: "Python", time: now - 1, type: "file" },
        { entity: "second.py", project: "api", branch: "<<LAST_BRANCH>>", language: "Python", time: now, type: "file" }
      ]
    )

    assert_equal [ nil, "main" ], user.heartbeats.where(entity: [ "first.py", "second.py" ]).order(:time).pluck(:branch)
  end

  test "heartbeat_unique_by targets the composite index once time_epoch exists" do
    ingest = HeartbeatIngest.new(user: User.new, mode: :direct, heartbeats: [])

    assert_equal [ :fields_hash ], ingest.send(:heartbeat_unique_by)

    with_time_epoch_column = Heartbeat.column_names + [ "time_epoch" ]
    Heartbeat.define_singleton_method(:column_names) { with_time_epoch_column }
    begin
      assert_equal %i[fields_hash time_epoch], ingest.send(:heartbeat_unique_by)
    ensure
      Heartbeat.singleton_class.remove_method(:column_names)
    end
  end

  test "partition_attrs supplies floor(time) as time_epoch only once the column exists" do
    ingest = HeartbeatIngest.new(user: User.new, mode: :direct, heartbeats: [])

    # pre-cutover / dev-and-test plain table: no-op
    assert_equal({}, ingest.send(:partition_attrs, 1_783_000_000.9))

    with_time_epoch_column = Heartbeat.column_names + [ "time_epoch" ]
    Heartbeat.define_singleton_method(:column_names) { with_time_epoch_column }
    begin
      assert_equal({ time_epoch: 1_783_000_000 }, ingest.send(:partition_attrs, 1_783_000_000.9))
      assert_equal({}, ingest.send(:partition_attrs, nil))
    ensure
      Heartbeat.singleton_class.remove_method(:column_names)
    end
  end

  test "set_time_epoch! populates the partition column when it exists" do
    hb = Heartbeat.new(time: 1_783_000_000.9)

    # column absent today: hook is a no-op and does not raise
    assert_nothing_raised { hb.send(:set_time_epoch!) }

    captured = []
    hb.define_singleton_method(:time_epoch=) { |v| captured << v }
    with_time_epoch = Heartbeat.column_names + [ "time_epoch" ]
    Heartbeat.define_singleton_method(:column_names) { with_time_epoch }
    begin
      hb.send(:set_time_epoch!)
      assert_equal [ 1_783_000_000 ], captured
    ensure
      Heartbeat.singleton_class.remove_method(:column_names)
    end
  end

  test "with_heartbeat_unique_by re-raises inside an open transaction after refreshing the schema cache" do
    ingest = HeartbeatIngest.new(user: User.new, mode: :direct, heartbeats: [])

    # transactional tests already wrap us in a transaction, so the guard applies
    calls = 0
    assert_raises(ArgumentError) do
      ingest.send(:with_heartbeat_unique_by) do |_unique_by|
        calls += 1
        raise ArgumentError, "No unique index found"
      end
    end
    assert_equal 1, calls
  end

  test "import heartbeat ingest deduplicates imported heartbeats and schedules dashboard rollup refresh" do
    user = User.create!(timezone: "UTC")

    assert_difference("user.heartbeats.count", 1) do
      assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ]) do
        result = HeartbeatIngest.call(
          user: user,
          mode: :import,
          heartbeats: [
            {
              entity: "/tmp/test.rb",
              type: "file",
              time: 1_700_000_000.0,
              project: "hackatime",
              language: "Ruby",
              is_write: true
            },
            {
              entity: "/tmp/test.rb",
              type: "file",
              time: 1_700_000_000.0,
              project: "hackatime",
              language: "Ruby",
              is_write: true
            }
          ]
        )

        assert_equal 2, result.total_count
        assert_equal 1, result.persisted_count
        assert_equal 1, result.duplicate_count
        assert_equal 0, result.failed_count
      end
    end

    heartbeat = user.heartbeats.order(:id).last
    assert_equal "wakapi_import", heartbeat.source_type
  end

  test "ClickHouse imports persist in bounded transactions" do
    previous_repository = HeartbeatRepository.instance_variable_get(:@current)
    repository = ImportBatchRepository.new
    HeartbeatRepository.instance_variable_set(:@current, repository)
    user = User.create!(timezone: "UTC")
    records = (HeartbeatIngest::CLICKHOUSE_IMPORT_BATCH_SIZE * 2 + 1).times.map do |index|
      {
        fields_hash: Digest::MD5.hexdigest("request-#{index}"),
        clickhouse_fields_hash: Digest::MD5.hexdigest("canonical-#{index}"),
        legacy_fields_hash: nil,
        time: 1_700_000_000.0 + index
      }
    end

    persisted = HeartbeatIngest.new(user:, mode: :import, heartbeats: [])
      .send(:persist_clickhouse_import, records)

    assert_equal records.length, persisted
    assert_equal [ 1_000, 1_000, 1 ], repository.batch_sizes
  ensure
    HeartbeatRepository.instance_variable_set(:@current, previous_repository)
  end

  test "the cutover write fence rejects direct and imported heartbeats" do
    previous = ENV["HEARTBEAT_WRITES_STOPPED"]
    ENV["HEARTBEAT_WRITES_STOPPED"] = "1"
    user = User.create!(timezone: "UTC")

    %i[direct import].each do |mode|
      error = assert_raises(RuntimeError) do
        HeartbeatIngest.call(user:, mode:, heartbeats: [])
      end
      assert_equal "Heartbeat writes are stopped", error.message
    end
  ensure
    ENV["HEARTBEAT_WRITES_STOPPED"] = previous
  end

  test "the online backfill mutation fence permits append-only ingestion" do
    previous = ENV["HEARTBEAT_MUTATIONS_STOPPED"]
    ENV["HEARTBEAT_MUTATIONS_STOPPED"] = "1"
    user = User.create!(timezone: "UTC")

    result = HeartbeatIngest.call(
      user:,
      mode: :direct,
      heartbeats: [ { entity: "backfill.rb", time: Time.current.to_f, type: "file" } ],
      schedule_rollup_refresh: false
    )

    assert_equal 1, result.persisted_count
  ensure
    ENV["HEARTBEAT_MUTATIONS_STOPPED"] = previous
  end

  private

  def create_legacy_imported_heartbeat(user, attributes)
    legacy_attributes = Heartbeat.indexed_attributes.index_with { nil }.symbolize_keys.merge(
      dependencies: [],
      is_write: false,
      user_id: user.id
    ).merge(attributes)
    heartbeat = user.heartbeats.create!(legacy_attributes.merge(source_type: :wakapi_import))
    heartbeat.update_column(:fields_hash, Heartbeat.generate_fields_hash(legacy_attributes))
    heartbeat
  end
end

# Outside a transaction (the production configuration for both ingest modes),
# the unique_by fallback must retry exactly once with a refreshed schema cache.
class HeartbeatIngestUniqueByFallbackTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "with_heartbeat_unique_by retries once after a schema-cache failure" do
    ingest = HeartbeatIngest.new(user: User.new, mode: :direct, heartbeats: [])

    calls = 0
    result = ingest.send(:with_heartbeat_unique_by) do |unique_by|
      calls += 1
      raise ActiveRecord::StatementInvalid, "no unique or exclusion constraint" if calls == 1
      unique_by
    end

    assert_equal 2, calls
    assert_equal [ :fields_hash ], result
  end

  test "with_heartbeat_unique_by does not retry more than once" do
    ingest = HeartbeatIngest.new(user: User.new, mode: :direct, heartbeats: [])

    calls = 0
    assert_raises(ActiveRecord::StatementInvalid) do
      ingest.send(:with_heartbeat_unique_by) do |_unique_by|
        calls += 1
        raise ActiveRecord::StatementInvalid, "no unique or exclusion constraint"
      end
    end
    assert_equal 2, calls
  end
end
