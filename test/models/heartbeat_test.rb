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

  test "today and custom days include the final fractional second across DST" do
    Time.use_zone("Europe/London") do
      [ "2026-03-29", "2026-10-25" ].each do |date|
        travel_to Time.zone.parse("#{date} 12:00:00") do
          user = create(:user)
          start = Time.current.beginning_of_day
          finish = start.next_day
          rows = [ start.to_f - 0.5, finish.to_f - 1.5, finish.to_f - 0.5, finish.to_f ].map do |time|
            create(:heartbeat, user:, time:, source_type: :test_entry)
          end
          [ user.heartbeats.today, user.heartbeats.filter_by_time_range("custom", date, date) ].each do |scope|
            assert_equal rows[1..2].map(&:id), scope.order(:time, :id).pluck(:id)
            assert_equal 1, scope.duration_seconds
          end
          assert_includes [ 23.hours, 25.hours ], finish - start
        end
      end
    end
  end

  test "soft delete hides record from default scope and restore brings it back" do
    user = create(:user)
    heartbeat = create(:heartbeat, user: user,
      entity: "src/main.rb",
      type: "file",
      category: "coding",
      time: Time.current.to_f,
      project: "heartbeat-test",
      source_type: :test_entry
    )

    assert_includes Heartbeat.all, heartbeat

    heartbeat.soft_delete

    assert_not_includes Heartbeat.all, heartbeat
    assert_includes Heartbeat.with_deleted, heartbeat

    heartbeat.restore

    assert_includes Heartbeat.all, heartbeat
  end

  test "daily streak cache is separated for browser-filtered leaderboard streaks" do
    user = create(:user, username: "hb_streak_cache")
    create_heartbeat_sequence(user: user, started_at: 1.day.ago.beginning_of_day + 9.hours, editor: "firefox")

    assert_equal 1, Heartbeat.daily_streaks_for_users([ user.id ])[user.id]
    assert_equal 0, Heartbeat.daily_streaks_for_users([ user.id ], exclude_browser_time: true)[user.id]
  end

  test "attributed_durations_by sums to total duration when every heartbeat has the field" do
    user = create(:user)
    base = Time.current.to_i.to_f
    languages = %w[ruby ruby python python javascript]
    languages.each_with_index do |lang, i|
      create(:heartbeat, user: user,
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

    scope = user.heartbeats.where(project: "attribution-full")
    buckets = Heartbeat.attributed_durations_by(scope, :language)
    total = scope.duration_seconds

    assert_equal 240, total
    assert_equal({ "ruby" => 60, "python" => 120, "javascript" => 60 }, buckets)
    assert_equal total, buckets.values.sum
    assert_not_includes buckets.keys, "Unknown"
    assert_not_includes buckets.keys, nil
    assert_not_includes buckets.keys, ""
  end

  test "attributed_durations_by excludes NULL/blank field values without inventing an Unknown bucket" do
    user = create(:user)
    base = Time.current.to_i.to_f
    rows = [
      { language: "ruby",   offset: 0   },
      { language: "ruby",   offset: 60  },
      { language: nil,      offset: 120 }, # NULL — excluded from buckets
      { language: "",       offset: 180 }, # blank — excluded from buckets
      { language: "python", offset: 240 }
    ]
    rows.each do |r|
      create(:heartbeat, user: user,
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

    scope = user.heartbeats.where(project: "attribution-nulls")
    buckets = Heartbeat.attributed_durations_by(scope, :language)
    total = scope.duration_seconds

    assert_equal 240, total
    assert_equal({ "ruby" => 60, "python" => 60 }, buckets)
    assert_equal total - 120, buckets.values.sum
    assert_not_includes buckets.keys, "Unknown"
    assert_not_includes buckets.keys, nil
    assert_not_includes buckets.keys, ""
  end

  test "creating a heartbeat schedules a dashboard rollup refresh" do
    user = create(:user)

    assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ]) do
      user.heartbeats.create!(
        entity: "src/main.rb",
        type: "file",
        category: "coding",
        editor: "vscode",
        time: Time.current.to_f,
        project: "heartbeat-test",
        source_type: :test_entry
      )
    end
  end

  private

  def create_heartbeat_sequence(user:, started_at:, editor:, count: 9)
    count.times do |offset|
      create(:heartbeat, user: user,
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
