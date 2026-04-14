require "test_helper"

class DashboardRollupRefreshServiceTest < ActiveSupport::TestCase
  test "rebuilds dashboard rollups from current heartbeat aggregates" do
    user = User.create!(timezone: "UTC")

    create_heartbeat(user, "2026-04-07 09:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
    create_heartbeat(user, "2026-04-07 09:01:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
    create_heartbeat(user, "2026-04-13 10:00:00 UTC", project: nil, language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
    create_heartbeat(user, "2026-04-13 10:01:00 UTC", project: nil, language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
    create_heartbeat(user, "2026-04-13 10:03:00 UTC", project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "coding")
    create_heartbeat(user, "2026-04-13 10:05:00 UTC", project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "browsing")

    DashboardRollupRefreshService.new(user: user).call

    total_row = DashboardRollup.find_by!(user: user, dimension: DashboardRollup::TOTAL_DIMENSION)

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
