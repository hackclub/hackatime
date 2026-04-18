require "test_helper"

class DashboardRollupRefreshServiceTest < ActiveSupport::TestCase
  test "rebuilds dashboard rollups from current heartbeat aggregates" do
    travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
      user = User.create!(timezone: "UTC")

      create_heartbeat(user, "2026-04-07 09:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      create_heartbeat(user, "2026-04-07 09:01:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      create_heartbeat(user, "2026-04-13 10:00:00 UTC", project: nil, language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      create_heartbeat(user, "2026-04-13 10:01:00 UTC", project: nil, language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      create_heartbeat(user, "2026-04-13 10:03:00 UTC", project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "coding")
      create_heartbeat(user, "2026-04-13 10:05:00 UTC", project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "browsing")
      create_heartbeat(user, "2026-04-14 09:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      create_heartbeat(user, "2026-04-14 09:01:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

      DashboardRollupRefreshService.new(user: user).call

      total_row = DashboardRollup.find_by!(user: user, dimension: DashboardRollup::TOTAL_DIMENSION)
      filter_options_row = DashboardRollup.find_by!(user: user, dimension: DashboardRollup::FILTER_OPTIONS_DIMENSION)
      activity_graph_row = DashboardRollup.find_by!(user: user, dimension: DashboardRollup::ACTIVITY_GRAPH_DIMENSION)
      today_stats_row = DashboardRollup.find_by!(user: user, dimension: DashboardRollup::TODAY_STATS_DIMENSION)

      assert_equal user.heartbeats.duration_seconds, total_row.total_seconds
      assert_equal user.heartbeats.count, total_row.source_heartbeats_count
      assert_equal user.heartbeats.maximum(:time), total_row.source_max_heartbeat_time

      assert_equal(
        user.heartbeats.group(:project).duration_seconds,
        DashboardRollup.where(user: user, dimension: "project").to_h { |row| [ row.bucket, row.total_seconds ] }
      )
      assert_equal(
        user.heartbeats.group(:language).duration_seconds,
        DashboardRollup.where(user: user, dimension: "language").to_h { |row| [ row.bucket, row.total_seconds ] }
      )

      assert_equal [ "alpha", "beta" ], filter_options_row.payload["project"]
      assert_equal [ "javascript", "ruby" ], filter_options_row.payload["language"]
      assert_equal [ "vscode", "zed" ], filter_options_row.payload["editor"]
      assert_equal [ "linux", "macos" ], filter_options_row.payload["operating_system"]
      assert_equal [ "browsing", "coding" ], filter_options_row.payload["category"]

      assert_equal "UTC", activity_graph_row.payload["timezone"]
      assert_equal "2025-04-14", activity_graph_row.payload["start_date"]
      assert_equal "2026-04-14", activity_graph_row.payload["end_date"]
      assert_equal 60, activity_graph_row.payload.fetch("duration_by_date").fetch("2026-04-14")

      assert_equal "UTC", today_stats_row.payload["timezone"]
      assert_equal "2026-04-14", today_stats_row.payload["today_date"]
      assert_equal 60, today_stats_row.payload["todays_duration_seconds"]
      assert_equal [ "Ruby" ], today_stats_row.payload["todays_language_categories"]
      assert_equal [ "vscode" ], today_stats_row.payload["todays_editor_keys"]
    end
  end

  private

  def create_heartbeat(user, timestamp, project:, language:, editor:, operating_system:, category:)
    Heartbeat.create!(
      user: user,
      time: Time.parse(timestamp).to_f,
      project: project,
      language: language,
      editor: editor,
      operating_system: operating_system,
      category: category,
      source_type: :test_entry
    )
  end
end
