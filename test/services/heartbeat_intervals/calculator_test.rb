require "test_helper"

class HeartbeatIntervals::CalculatorTest < ActiveSupport::TestCase
  test "calculates user and filter intervals in one ordered pass" do
    base = Time.utc(2026, 7, 10, 12)
    rows = [
      heartbeat_row(id: 3, time: base + 120.seconds, language: "Ruby"),
      heartbeat_row(id: 1, time: base, language: "Ruby"),
      heartbeat_row(id: 2, time: base + 60.seconds, language: "Python")
    ]

    deltas = HeartbeatIntervals::Calculator.call(rows, reason: "test")

    assert_equal [ 0, 60, 60 ], deltas.pluck(:user_seconds_delta)
    assert_equal [ 0, 0, 120 ], deltas.pluck("language_seconds_delta")
    assert_equal %w[Ruby Python Ruby], deltas.pluck(:language)
  end

  test "caps long gaps and ignores deleted or invalid rows" do
    base = Time.utc(2026, 7, 10, 12)
    rows = [
      heartbeat_row(id: 1, time: base),
      heartbeat_row(id: 2, time: base + 10.minutes),
      heartbeat_row(id: 3, time: base + 11.minutes, deleted_at: Time.current),
      heartbeat_row(id: 4, time: -1)
    ]

    deltas = HeartbeatIntervals::Calculator.call(rows, reason: "test")

    assert_equal 2, deltas.length
    assert_equal [ 0, Clickhouse::Heartbeat.heartbeat_timeout_duration.to_i ], deltas.pluck(:user_seconds_delta)
  end

  private

  def heartbeat_row(id:, time:, language: "Ruby", deleted_at: nil)
    {
      id: id,
      user_id: 42,
      time: time.to_f,
      project: "calculator",
      language: language,
      editor: "vscode",
      operating_system: "macOS",
      machine: "laptop",
      category: "coding",
      entity: "app.rb",
      branch: "main",
      deleted_at: deleted_at
    }
  end
end
