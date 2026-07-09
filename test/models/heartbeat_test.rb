require "test_helper"

class HeartbeatTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

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

  test "soft delete hides record from default scope and restore brings it back" do
    user = User.create!(timezone: "UTC")
    heartbeat = create_heartbeat(
      user: user,
      entity: "src/main.rb",
      type: "file",
      category: "coding",
      time: Time.current.to_f,
      project: "heartbeat-test",
      source_type: :test_entry
    )

    assert_includes Clickhouse::Heartbeat.all.map(&:id), heartbeat.id

    soft_delete_heartbeat(heartbeat)

    assert_not_includes Clickhouse::Heartbeat.all.map(&:id), heartbeat.id
    assert_includes Clickhouse::Heartbeat.with_deleted.map(&:id), heartbeat.id

    restore_heartbeat(heartbeat)

    assert_includes Clickhouse::Heartbeat.all.map(&:id), heartbeat.id
  end

  test "daily streak cache is separated for browser-filtered leaderboard streaks" do
    user = User.create!(timezone: "UTC", username: "hb_streak_cache")
    create_heartbeat_sequence(user: user, started_at: 1.day.ago.beginning_of_day + 9.hours, editor: "firefox")

    assert_equal 1, Clickhouse::Heartbeat.daily_streaks_for_users([ user.id ])[user.id]
    assert_equal 0, Clickhouse::Heartbeat.daily_streaks_for_users([ user.id ], exclude_browser_time: true)[user.id]
  end

  test "attributed_durations_by sums to total duration when every heartbeat has the field" do
    user = User.create!(timezone: "UTC")
    base = Time.current.to_i.to_f
    languages = %w[ruby ruby python python javascript]
    languages.each_with_index do |lang, i|
      create_heartbeat(
        user: user,
        entity: "src/#{lang}.rb",
        type: "file",
        category: "coding",
        editor: "vscode",
        language: lang,
        time: base + (i * 60),
        project: "attribution-full",
        source_type: :test_entry
      )
    end

    scope = Clickhouse::Heartbeat.for_user(user).where(project: "attribution-full")
    buckets = Clickhouse::Heartbeat.attributed_durations_by(scope, :language)
    total = scope.duration_seconds

    assert_equal 240, total
    assert_equal({ "ruby" => 60, "python" => 120, "javascript" => 60 }, buckets)
    assert_equal total, buckets.values.sum
    assert_not_includes buckets.keys, "Unknown"
    assert_not_includes buckets.keys, nil
    assert_not_includes buckets.keys, ""
  end

  test "attributed_durations_by excludes NULL/blank field values without inventing an Unknown bucket" do
    user = User.create!(timezone: "UTC")
    base = Time.current.to_i.to_f
    rows = [
      { language: "ruby",   offset: 0   },
      { language: "ruby",   offset: 60  },
      { language: nil,      offset: 120 }, # NULL — excluded from buckets
      { language: "",       offset: 180 }, # blank — excluded from buckets
      { language: "python", offset: 240 }
    ]
    rows.each do |r|
      create_heartbeat(
        user: user,
        entity: "src/file.rb",
        type: "file",
        category: "coding",
        editor: "vscode",
        language: r[:language],
        time: base + r[:offset],
        project: "attribution-nulls",
        source_type: :test_entry
      )
    end

    scope = Clickhouse::Heartbeat.for_user(user).where(project: "attribution-nulls")
    buckets = Clickhouse::Heartbeat.attributed_durations_by(scope, :language)
    total = scope.duration_seconds

    assert_equal 240, total
    assert_equal({ "ruby" => 60, "python" => 60 }, buckets)
    assert_equal total - 120, buckets.values.sum
    assert_not_includes buckets.keys, "Unknown"
    assert_not_includes buckets.keys, nil
    assert_not_includes buckets.keys, ""
  end

  test "same-timestamp attribution ties break by id like the legacy Postgres path" do
    user = User.create!(timezone: "UTC")
    base = Time.current.to_i.to_f
    create_heartbeat(user: user, id: 100, time: base, project: "ties", language: "text",
      entity: "a.txt", type: "file", category: "coding", editor: "vscode", source_type: :test_entry)
    create_heartbeat(user: user, id: 200, time: base + 60, project: "ties", language: "ruby",
      entity: "b.rb", type: "file", category: "coding", editor: "vscode", source_type: :test_entry)
    create_heartbeat(user: user, id: 150, time: base + 60, project: "ties", language: "python",
      entity: "c.py", type: "file", category: "coding", editor: "vscode", source_type: :test_entry)

    scope = Clickhouse::Heartbeat.for_user(user).where(project: "ties")
    buckets = Clickhouse::Heartbeat.attributed_durations_by(scope, :language)

    # Gap of 60s lands on the first row at the tied timestamp (lowest id);
    # the second tied row contributes a zero-length diff.
    assert_equal 60, buckets["python"]
    assert_equal 0, buckets["ruby"]
    assert_equal 0, buckets["text"]
  end

  test "streaks preserve the Postgres LEAST(NULL, timeout) quirk: first heartbeat of a day counts the full timeout" do
    user = User.create!(timezone: "UTC", username: "hb_quirk_#{SecureRandom.hex(4)}")
    # One heartbeat + 7 more at 2min gaps = 14min of gaps + 120s first-row
    # contribution = 15min: exactly the streak threshold.
    create_heartbeat_sequence(user: user, started_at: 1.day.ago.beginning_of_day + 9.hours, editor: "vscode", count: 8)

    assert_equal 1, Clickhouse::Heartbeat.daily_streaks_for_users([ user.id ])[user.id]
  end

  test "daily_durations preserves the caller relation scope" do
    travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
      user = User.create!(timezone: "UTC")
      other_user = User.create!(timezone: "UTC")
      user_day = Time.current.beginning_of_day + 10.hours
      other_day = 1.day.ago.beginning_of_day + 10.hours

      create_heartbeat(user: user, time: user_day.to_f, project: "scoped", category: "coding", source_type: :test_entry)
      create_heartbeat(user: user, time: (user_day + 60.seconds).to_f, project: "scoped", category: "coding", source_type: :test_entry)
      create_heartbeat(user: other_user, time: other_day.to_f, project: "other", category: "coding", source_type: :test_entry)
      create_heartbeat(user: other_user, time: (other_day + 60.seconds).to_f, project: "other", category: "coding", source_type: :test_entry)

      durations = Clickhouse::Heartbeat.for_user(user).daily_durations(user_timezone: "UTC").to_h

      assert_equal [ user_day.to_date ], durations.keys
      assert_equal 60, durations[user_day.to_date]
    end
  end

  test "to_span preserves the caller relation scope" do
    travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
      user = User.create!(timezone: "UTC")
      other_user = User.create!(timezone: "UTC")
      base = Time.current.beginning_of_day + 9.hours
      other_base = base + 4.hours

      create_heartbeat(user: user, time: base.to_f, project: "scoped", category: "coding", source_type: :test_entry)
      create_heartbeat(user: user, time: (base + 60.seconds).to_f, project: "scoped", category: "coding", source_type: :test_entry)
      create_heartbeat(user: other_user, time: other_base.to_f, project: "other", category: "coding", source_type: :test_entry)
      create_heartbeat(user: other_user, time: (other_base + 60.seconds).to_f, project: "other", category: "coding", source_type: :test_entry)

      spans = Clickhouse::Heartbeat.for_user(user).where(time: base.to_f...(base + 2.hours).to_f).to_span

      assert_equal 1, spans.length
      assert_equal base.to_f, spans.first[:start_time]
      assert_equal 60, spans.first[:duration]
    end
  end

  test "generate_fields_hash is stable and insensitive to key types" do
    attrs = { user_id: 7, entity: "a.rb", time: 1_700_000_000.5, language: "Ruby", is_write: true }
    hash_from_symbols = Clickhouse::Heartbeat.generate_fields_hash(attrs)
    hash_from_strings = Clickhouse::Heartbeat.generate_fields_hash(attrs.transform_keys(&:to_s))

    assert_equal hash_from_symbols, hash_from_strings
    assert_equal 32, hash_from_symbols.length

    different = Clickhouse::Heartbeat.generate_fields_hash(attrs.merge(entity: "b.rb"))
    assert_not_equal hash_from_symbols, different
  end

  test "generate_fields_hash matches the legacy Postgres digest" do
    attrs = {
      branch: "main",
      category: "coding",
      cursorpos: 17,
      dependencies: [ "rails", "svelte" ],
      editor: "vscode",
      entity: "app/models/user.rb",
      is_write: true,
      language: "Ruby",
      line_additions: 3,
      line_deletions: 1,
      lineno: 42,
      lines: 120,
      machine: "laptop",
      operating_system: "macOS",
      project: "hackatime",
      project_root_count: 1,
      time: 1_700_000_000.5,
      type: "file",
      user_agent: "vscode/1.0.0",
      user_id: 123
    }

    assert_equal "2f720968efb2caf0c1f10601b724b0ca", Clickhouse::Heartbeat.generate_fields_hash(attrs)
  end

  test "writer ids are JS-safe and time-ordered" do
    id_now = Clickhouse::HeartbeatWriter.generate_id
    id_future = Clickhouse::HeartbeatWriter.generate_id(1.hour.from_now)

    assert id_now < 2**53, "ids must stay within JS-safe integer range"
    assert id_future > id_now
  end

  test "merge_user_heartbeats skips rows whose latest version is deleted" do
    older = User.create!(timezone: "UTC")
    newer = User.create!(timezone: "UTC")
    live = create_heartbeat(user: newer, time: Time.current.to_f, project: "live", source_type: :test_entry)
    deleted = create_heartbeat(user: newer, time: 1.minute.from_now.to_f, project: "deleted", source_type: :test_entry)

    soft_delete_heartbeat(deleted)
    Clickhouse::HeartbeatWriter.merge_user_heartbeats!(older_user_id: older.id, newer_user_id: newer.id)

    assert_equal [ live.fields_hash ], Clickhouse::Heartbeat.for_user(older).pluck(:fields_hash)
    assert_empty Clickhouse::Heartbeat.for_user(newer)
  end

  private

  def create_heartbeat_sequence(user:, started_at:, editor:, count: 9)
    count.times do |offset|
      create_heartbeat(
        user: user,
        entity: "src/#{editor}.rb",
        type: "file",
        category: "coding",
        editor: editor,
        time: (started_at + (offset * 2).minutes).to_f,
        project: "heartbeat-test",
        source_type: :test_entry
      )
    end
  end
end
