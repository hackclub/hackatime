require "test_helper"

class DashboardDataTest < ActiveSupport::TestCase
  setup do
    @original_timeout = Heartbeat.heartbeat_timeout_duration
    Heartbeat.heartbeat_timeout_duration(1.second)
  end

  teardown do
    Heartbeat.heartbeat_timeout_duration(@original_timeout)
  end

  test "weekly_project_stats_for groups project durations by week and excludes archived projects" do
    travel_to Time.utc(2026, 1, 14, 12, 0, 0) do
      user = User.create!(timezone: "UTC")
      controller = StaticPagesController.new

      create_heartbeat_pair(user, Time.utc(2026, 1, 14, 9, 0, 0), project: "alpha")
      create_heartbeat_pair(user, Time.utc(2026, 1, 7, 9, 0, 0), project: "beta")
      create_heartbeat_pair(user, Time.utc(2026, 1, 14, 11, 0, 0), project: "gamma")

      archived = { "gamma" => true }
      stats = Time.use_zone("UTC") do
        controller.send(:weekly_project_stats_for, user.heartbeats, archived)
      end

      assert_equal({ "alpha" => 1 }, stats["2026-01-12"])
      assert_equal({ "beta" => 1 }, stats["2026-01-05"])
      assert_not_includes stats["2026-01-12"].keys, "gamma"
    end
  end

  private

  def create_heartbeat_pair(user, started_at, project:)
    user.heartbeats.create!(
      category: "coding",
      project: project,
      editor: "vscode",
      time: started_at.to_f,
      source_type: :test_entry
    )
    user.heartbeats.create!(
      category: "coding",
      project: project,
      editor: "vscode",
      time: (started_at + 1.second).to_f,
      source_type: :test_entry
    )
  end
end
