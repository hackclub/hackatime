require "test_helper"

class SailorsLogTest < ActiveSupport::TestCase
  test "initializes project summary from serving tables" do
    user = User.create!(slack_uid: "USAIL#{SecureRandom.hex(4)}", timezone: "UTC")
    base = Time.zone.local(2026, 7, 10, 12)

    create_heartbeat(user:, time: base.to_f, project: "alpha", category: "coding")
    create_heartbeat(user:, time: (base + 60.seconds).to_f, project: "alpha", category: "coding")

    heartbeat_queries = collect_heartbeat_queries do
      log = SailorsLog.create!(slack_uid: user.slack_uid)
      assert_equal({ "alpha" => 60 }, log.projects_summary)
    end

    assert_empty heartbeat_queries
  end

  private

  def create_heartbeat(user:, time:, project:, category:)
    super(
      user: user,
      source_type: :direct_entry,
      time: time,
      project: project,
      category: category
    )
  end

  def collect_heartbeat_queries
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      sql = payload[:sql].to_s
      queries << sql if sql.match?(/\bFROM\s+`?heartbeats`?\b/i)
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
