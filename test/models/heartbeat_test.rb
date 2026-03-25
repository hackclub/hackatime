require "test_helper"

class HeartbeatTest < ActiveSupport::TestCase
  def setup
    Rails.cache.clear
  end

  test "lightweight delete removes record from queries" do
    user = User.create!
    heartbeat = user.heartbeats.create!(
      entity: "src/main.rb",
      type: "file",
      category: "coding",
      time: Time.current.to_f,
      project: "heartbeat-test",
      source_type: :test_entry
    )

    assert_includes Heartbeat.all, heartbeat

    heartbeat.delete

    # After lightweight delete, the row is invisible to subsequent queries
    assert_not_includes Heartbeat.where(user_id: user.id).to_a, heartbeat
  end

  test "create bumps the user's heartbeat cache version" do
    user = User.create!(timezone: "UTC")
    initial_version = HeartbeatCacheInvalidator.version_for(user)

    user.heartbeats.create!(
      entity: "src/cache_bump.rb",
      type: "file",
      category: "coding",
      time: Time.current.to_f,
      project: "heartbeat-cache",
      source_type: :test_entry
    )

    assert_equal initial_version + 1, HeartbeatCacheInvalidator.version_for(user)
  end

  test "duration_seconds uses daily summary rows for simple user date ranges" do
    travel_to Time.utc(2026, 1, 10, 12, 0, 0) do
      user = User.create!(timezone: "UTC")

      create_heartbeat(
        user: user,
        time: Time.utc(2026, 1, 1, 10, 0, 0),
        updated_at: Time.utc(2026, 1, 1, 10, 0, 0)
      )
      create_heartbeat(
        user: user,
        time: Time.utc(2026, 1, 1, 10, 1, 0),
        updated_at: Time.utc(2026, 1, 1, 10, 1, 0)
      )
      create_heartbeat(
        user: user,
        time: Time.utc(2026, 1, 2, 12, 0, 0),
        updated_at: Time.utc(2026, 1, 2, 12, 0, 0)
      )
      create_heartbeat(
        user: user,
        time: Time.utc(2026, 1, 2, 12, 1, 30),
        updated_at: Time.utc(2026, 1, 2, 12, 1, 30)
      )

      create_daily_summary(user: user, day: Date.new(2026, 1, 1), duration_s: 60, heartbeats: 2)
      create_daily_summary(user: user, day: Date.new(2026, 1, 2), duration_s: 90, heartbeats: 2)

      total, queries = capture_sql_queries do
        user.heartbeats.where(time: Time.utc(2026, 1, 1).to_f..Time.utc(2026, 1, 2, 23, 59, 59).to_f).duration_seconds
      end

      assert_equal 270, total
      assert queries.any? { |sql| sql.include?("heartbeat_user_daily_summary FINAL") }
    end
  end

  test "duration_seconds preserves cross-day gaps when combining daily summaries" do
    travel_to Time.utc(2026, 1, 10, 12, 0, 0) do
      user = User.create!(timezone: "UTC")

      create_heartbeat(
        user: user,
        time: Time.utc(2026, 1, 1, 23, 59, 30),
        updated_at: Time.utc(2026, 1, 1, 23, 59, 30)
      )
      create_heartbeat(
        user: user,
        time: Time.utc(2026, 1, 2, 0, 0, 30),
        updated_at: Time.utc(2026, 1, 2, 0, 0, 30)
      )

      create_daily_summary(user: user, day: Date.new(2026, 1, 1), duration_s: 0, heartbeats: 1)
      create_daily_summary(user: user, day: Date.new(2026, 1, 2), duration_s: 0, heartbeats: 1)

      total = user.heartbeats.where(time: Time.utc(2026, 1, 1).to_f..Time.utc(2026, 1, 2, 23, 59, 59).to_f).duration_seconds

      assert_equal 60, total
    end
  end

  test "duration_seconds keeps filtered scopes on the raw heartbeat path" do
    travel_to Time.utc(2026, 1, 10, 12, 0, 0) do
      user = User.create!(timezone: "UTC")

      create_heartbeat(
        user: user,
        time: Time.utc(2026, 1, 1, 10, 0, 0),
        project: "alpha",
        updated_at: Time.utc(2026, 1, 1, 10, 0, 0)
      )
      create_heartbeat(
        user: user,
        time: Time.utc(2026, 1, 1, 10, 1, 0),
        project: "alpha",
        updated_at: Time.utc(2026, 1, 1, 10, 1, 0)
      )
      create_heartbeat(
        user: user,
        time: Time.utc(2026, 1, 1, 11, 0, 0),
        project: "beta",
        updated_at: Time.utc(2026, 1, 1, 11, 0, 0)
      )
      create_heartbeat(
        user: user,
        time: Time.utc(2026, 1, 1, 11, 1, 30),
        project: "beta",
        updated_at: Time.utc(2026, 1, 1, 11, 1, 30)
      )

      create_daily_summary(user: user, day: Date.new(2026, 1, 1), duration_s: 150, heartbeats: 4)

      total, queries = capture_sql_queries do
        user.heartbeats.where(project: "alpha", time: Time.utc(2026, 1, 1).to_f..Time.utc(2026, 1, 1, 23, 59, 59).to_f).duration_seconds
      end

      assert_equal 60, total
      assert queries.none? { |sql| sql.include?("heartbeat_user_daily_summary FINAL") }
    end
  end

  private

  def create_heartbeat(user:, time:, project: "heartbeat-test", updated_at:)
    Heartbeat.create!(
      user: user,
      entity: "src/main.rb",
      type: "file",
      category: "coding",
      time: time.to_f,
      project: project,
      source_type: :test_entry,
      created_at: updated_at,
      updated_at: updated_at
    )
  end

  def create_daily_summary(user:, day:, duration_s:, heartbeats:)
    HeartbeatUserDailySummary.create!(
      user_id: user.id,
      day: day,
      duration_s: duration_s,
      heartbeats: heartbeats
    )
  end

  def capture_sql_queries
    queries = []
    result = nil

    callback = lambda do |_name, _start, _finish, _id, payload|
      sql = payload[:sql]
      queries << sql if sql.is_a?(String)
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      result = yield
    end

    [ result, queries ]
  end
end
