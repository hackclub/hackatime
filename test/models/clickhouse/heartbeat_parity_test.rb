require "test_helper"

# Every ClickHouse primitive must match its Postgres counterpart within 1s
# (Postgres rounds via ::integer, ClickHouse rounds in Ruby).
module Clickhouse
  class HeartbeatParityTest < ActiveSupport::TestCase
    TIMEOUT = ::Heartbeat.heartbeat_timeout_duration.to_i

    setup do
      Rails.cache.clear

      @now = Time.current
      @user_utc = User.create!(timezone: "UTC", username: "parity_utc_#{SecureRandom.hex(4)}")
      @user_ny = User.create!(timezone: "America/New_York", username: "parity_ny_#{SecureRandom.hex(4)}")
      @user_tokyo = User.create!(timezone: "Asia/Tokyo", username: "parity_tokyo_#{SecureRandom.hex(4)}")
      @user_ids = [ @user_utc.id, @user_ny.id, @user_tokyo.id ]

      Clickhouse::HeartbeatMirror.with_mirroring { build_fixtures }
    end

    test "duration_seconds parity across ranges and shapes" do
      each_range do |range_name, range|
        each_shape do |shape_name, pg_scope, ch_scope|
          pg_scope = pg_scope.where(time: range) if range
          ch_scope = ch_scope.where(time: range) if range

          assert_in_delta pg_scope.duration_seconds, ch_scope.duration_seconds, 1,
            "duration_seconds mismatch for #{range_name} / #{shape_name}"
        end
      end
    end

    test "duration_seconds grouped by project parity" do
      each_range do |range_name, range|
        pg_scope = @user_utc.heartbeats
        ch_scope = ch_user_scope(@user_utc)
        pg_scope = pg_scope.where(time: range) if range
        ch_scope = ch_scope.where(time: range) if range

        assert_hash_in_delta pg_scope.group(:project).duration_seconds,
          ch_scope.group(:project).duration_seconds,
          "grouped duration_seconds mismatch for #{range_name}"
      end
    end

    test "duration_seconds_boundary_aware parity" do
      start_time = (@now - 90.minutes).to_f
      end_time = @now.to_f

      pg = ::Heartbeat.duration_seconds_boundary_aware(@user_utc.heartbeats, start_time, end_time)
      ch = Clickhouse::Heartbeat.duration_seconds_boundary_aware(ch_user_scope(@user_utc), start_time, end_time)
      assert_in_delta pg, ch, 1, "boundary_aware mismatch"

      pg = ::Heartbeat.duration_seconds_boundary_aware(
        @user_utc.heartbeats, start_time, end_time, excluded_categories: [ "browsing" ]
      )
      ch = Clickhouse::Heartbeat.duration_seconds_boundary_aware(
        ch_user_scope(@user_utc), start_time, end_time, excluded_categories: [ "browsing" ]
      )
      assert_in_delta pg, ch, 1, "boundary_aware with excluded_categories mismatch"
    end

    test "daily_durations parity per timezone" do
      [ @user_utc, @user_ny, @user_tokyo ].each do |user|
        pg = user.heartbeats.daily_durations(user_timezone: user.timezone).to_h
        ch = ch_user_scope(user).daily_durations(user_timezone: user.timezone).to_h

        assert_hash_in_delta pg, ch, "daily_durations mismatch for #{user.timezone}"
      end
    end

    test "attributed_durations_by parity" do
      %i[language editor].each do |field|
        each_range do |range_name, range|
          pg_scope = @user_utc.heartbeats
          ch_scope = ch_user_scope(@user_utc)
          pg_scope = pg_scope.where(time: range) if range
          ch_scope = ch_scope.where(time: range) if range

          assert_hash_in_delta ::Heartbeat.attributed_durations_by(pg_scope, field),
            Clickhouse::Heartbeat.attributed_durations_by(ch_scope, field),
            "attributed_durations_by(#{field}) mismatch for #{range_name}"
        end
      end
    end

    test "attributed_durations_by matches Postgres id ordering for same-timestamp ties" do
      user = User.create!(timezone: "UTC", username: "tie_#{SecureRandom.hex(4)}")
      previous = create_heartbeat(user, time: @now - 10.minutes, project: "ties", language: "text", editor: "vscode")
      first_at_time = create_heartbeat(user, time: @now - 9.minutes, project: "ties", language: "ruby", editor: "vscode")
      second_at_time = create_heartbeat(user, time: @now - 9.minutes, project: "ties", language: "python", editor: "vscode")

      previous.update_columns(fields_hash: "8" * 32)
      first_at_time.update_columns(fields_hash: "f" * 32)
      second_at_time.update_columns(fields_hash: "0" * 32)
      Clickhouse::HeartbeatMirror.with_mirroring do
        [ previous, first_at_time, second_at_time ].each { |heartbeat| Clickhouse::HeartbeatMirror.upsert(heartbeat.reload) }
      end

      pg_scope = user.heartbeats.where(project: "ties")
      ch_scope = ch_user_scope(user).where(project: "ties")

      assert_hash_in_delta ::Heartbeat.attributed_durations_by(pg_scope, :language),
        Clickhouse::Heartbeat.attributed_durations_by(ch_scope, :language),
        "same-timestamp language attribution must match Postgres id ordering"
    end

    test "to_span parity" do
      each_range do |range_name, range|
        pg_scope = @user_utc.heartbeats
        ch_scope = ch_user_scope(@user_utc)
        pg_scope = pg_scope.where(time: range) if range
        ch_scope = ch_scope.where(time: range) if range

        pg_spans = pg_scope.to_span
        ch_spans = ch_scope.to_span

        assert_equal pg_spans.length, ch_spans.length, "span count mismatch for #{range_name}"
        pg_spans.zip(ch_spans).each do |pg_span, ch_span|
          assert_in_delta pg_span[:start_time], ch_span[:start_time], 1, "span start mismatch for #{range_name}"
          assert_in_delta pg_span[:end_time], ch_span[:end_time], 1, "span end mismatch for #{range_name}"
          assert_in_delta pg_span[:duration], ch_span[:duration], 1, "span duration mismatch for #{range_name}"
        end
      end
    end

    test "daily_streaks_for_users parity" do
      [ false, true ].each do |exclude_browser_time|
        Rails.cache.clear
        pg = ::Heartbeat.daily_streaks_for_users(@user_ids, exclude_browser_time: exclude_browser_time)
        Rails.cache.clear
        ch = Clickhouse::Heartbeat.daily_streaks_for_users(@user_ids, exclude_browser_time: exclude_browser_time)

        assert_equal pg, ch, "daily_streaks mismatch (exclude_browser_time: #{exclude_browser_time})"
      end
    end

    test "duplicate mirrored rows collapse under FINAL" do
      heartbeat = @user_utc.heartbeats.order(:time).first

      Clickhouse::HeartbeatMirror.with_mirroring { Clickhouse::HeartbeatMirror.upsert(heartbeat) }

      pg = @user_utc.heartbeats.duration_seconds
      ch = ch_user_scope(@user_utc).duration_seconds
      assert_in_delta pg, ch, 1, "duplicate mirror row corrupted duration parity"
    end

    test "soft deleted heartbeats are excluded on both sides" do
      pg_count = @user_utc.heartbeats.count
      ch_count = ch_user_scope(@user_utc).final.count
      assert_equal pg_count, ch_count, "live row count mismatch (soft-deleted row leaked)"
    end

    private

    def each_range(&block)
      {
        "today" => @now.beginning_of_day..@now.end_of_day,
        "24h" => (@now - 24.hours)..@now,
        "7d" => (@now - 7.days)..@now,
        "14d" => (@now - 14.days)..@now,
        "3y" => (@now - 3.years)..@now,
        "all" => nil,
        "historical_window" => (@now - 3.years - 1.day)..(@now - 3.years + 1.day)
      }.each(&block)
    end

    def each_shape
      yield "base", @user_utc.heartbeats, ch_user_scope(@user_utc)
      yield "project", @user_utc.heartbeats.where(project: "alpha"), ch_user_scope(@user_utc).where(project: "alpha")
      yield "category", @user_utc.heartbeats.coding_only, ch_user_scope(@user_utc).coding_only
    end

    def ch_user_scope(user) = Clickhouse::Heartbeat.where(user_id: user.id)

    def assert_hash_in_delta(pg_hash, ch_hash, message)
      assert_equal pg_hash.keys.sort_by(&:to_s), ch_hash.keys.sort_by(&:to_s), "#{message} (keys)"
      pg_hash.each do |key, pg_value|
        assert_in_delta pg_value, ch_hash[key], 1, "#{message} (bucket #{key.inspect})"
      end
    end

    def build_fixtures
      create_burst(@user_utc, start: @now - 2.hours, count: 5, gap: 30.seconds,
        project: "alpha", language: "ruby", editor: "vscode")
      create_burst(@user_utc, start: @now - 1.hour, count: 4, gap: 60.seconds,
        project: "beta", language: "python", editor: "zed")

      create_heartbeat(@user_utc, time: @now - 50.minutes, project: "beta",
        language: "python", editor: "chrome", category: "browsing")
      create_heartbeat(@user_utc, time: @now - 49.minutes, project: "beta",
        language: "python", editor: "firefox", category: "coding")

      create_heartbeat(@user_utc, time: @now - 40.minutes, project: nil,
        language: "", editor: "vscode", category: "coding")

      create_heartbeat(@user_utc, time: @now - 91.minutes, project: "alpha",
        language: "ruby", editor: "vscode", category: "coding")

      create_burst(@user_utc, start: @now - 8.days, count: 3, gap: 45.seconds,
        project: "alpha", language: "ruby", editor: "vscode")

      create_burst(@user_utc, start: @now - 3.years, count: 4, gap: 90.seconds,
        project: "legacy", language: "go", editor: "vim")

      deleted = create_heartbeat(@user_utc, time: @now - 2.hours + 45.seconds,
        project: "alpha", language: "ruby", editor: "vscode", category: "coding")
      deleted.soft_delete

      ny_midnight = @now.in_time_zone("America/New_York").beginning_of_day
      create_burst(@user_ny, start: ny_midnight - 20.minutes, count: 3, gap: 5.minutes,
        project: "nightowl", language: "ruby", editor: "vscode")
      create_burst(@user_ny, start: ny_midnight + 10.minutes, count: 3, gap: 5.minutes,
        project: "nightowl", language: "ruby", editor: "vscode")
      3.times do |day_offset|
        create_burst(@user_ny, start: @now - (day_offset + 1).days, count: 9, gap: 2.minutes,
          project: "streaky", language: "ruby", editor: "vscode")
      end

      tokyo_now = @now.in_time_zone("Asia/Tokyo")
      create_burst(@user_tokyo, start: tokyo_now.beginning_of_day + 9.hours, count: 9, gap: 2.minutes,
        project: "tokyo", language: "rust", editor: "zed")
      create_burst(@user_tokyo, start: tokyo_now.beginning_of_day - 10.hours, count: 9, gap: 2.minutes,
        project: "tokyo", language: "rust", editor: "zed")
    end

    def create_burst(user, start:, count:, gap:, project:, language:, editor:, category: "coding")
      count.times do |i|
        create_heartbeat(user, time: start + (i * gap), project: project,
          language: language, editor: editor, category: category)
      end
    end

    def create_heartbeat(user, time:, project:, language:, editor:, category: "coding")
      user.heartbeats.create!(
        entity: "src/#{language.presence || 'file'}.rb",
        type: "file",
        category: category,
        editor: editor,
        language: language,
        time: time.to_f,
        project: project,
        source_type: :test_entry
      )
    end
  end
end
