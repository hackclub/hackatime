require "test_helper"

class HeartbeatRollupTest < ActiveSupport::TestCase
  Snapshots = DashboardData::Snapshots

  test "snapshot matches the live dashboard queries" do
    travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
      user = create(:user, timezone: "America/New_York")
      # Gaps cross projects, local midnight, a week boundary and the timeout.
      [
        [ "2026-04-05 03:58:30", "alpha", "ruby", "vscode", "macos", "coding" ],
        [ "2026-04-05 03:59:40", "alpha", "ruby", "vscode", "macos", "coding" ],
        [ "2026-04-06 03:59:00", "beta", "javascript", "zed", "linux", "coding" ],
        [ "2026-04-06 04:00:30", "beta", "javascript", "zed", "linux", "browsing" ],
        [ "2026-04-06 04:01:00", "alpha", "ruby", "vscode", "macos", "coding" ],
        [ "2026-04-13 10:00:00", nil, "ruby", "vscode", "macos", "coding" ],
        [ "2026-04-13 10:01:00", nil, "ruby", "vscode", "macos", "coding" ],
        [ "2026-04-13 10:01:30.25", "", "Ruby", "VS Code", "macOS", "coding" ],
        [ "2026-04-14 09:00:00", "alpha", "ruby", "vscode", "macos", "ai coding" ],
        [ "2026-04-14 09:00:59.5", "alpha", "python", "vim", "linux", "ai coding" ],
        [ "2026-04-14 09:05:00", "alpha", "python", "vim", "linux", "ai coding" ],
        [ "2025-01-01 00:00:00", "ancient", "go", "vim", "linux", "coding" ]
      ].each { |time, project, language, editor, os, category| create_heartbeat(user, "#{time} UTC", project:, language:, editor:, operating_system: os, category:) }

      HeartbeatRollup.rebuild!(user)
      snapshot = HeartbeatRollup.dashboard_snapshot(HeartbeatRollupState.current_for(user))
      scope = user.heartbeats_excluding_archived_projects

      live = Snapshots.aggregate_query_snapshot(user:, scope:)
      assert_equal live[:total_time], snapshot[:total_time]
      assert_equal live[:total_heartbeats], snapshot[:total_heartbeats]
      assert_equal live[:grouped_durations], snapshot[:grouped_durations]
      assert_equal live[:weekly_project_stats], snapshot[:weekly_project_stats]
      assert_equal live[:coding_rhythm][:duration_by_slot], snapshot[:coding_rhythm][:duration_by_slot]
      assert_equal Snapshots.activity_graph_snapshot(user:, scope:), snapshot[:activity_graph]
      assert_equal Snapshots.today_stats_snapshot(user:, scope:), snapshot[:today_stats]
      assert_equal Snapshots.project_details_snapshot(scope:), snapshot[:project_details]
      assert_equal(
        HeartbeatRollup::DIMENSIONS.index_with { |field| scope.distinct.pluck(field).compact_blank.sort },
        snapshot[:filter_options]
      )
      assert_operator snapshot[:total_time], :>, 0
    end
  end

  test "groups coding rhythm in the user's local weekday and hour" do
    user = create(:user, timezone: "America/Los_Angeles")
    create_heartbeat(user, "2026-04-13 01:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
    create_heartbeat(user, "2026-04-13 01:01:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

    HeartbeatRollup.rebuild!(user)

    snapshot = HeartbeatRollup.dashboard_snapshot(HeartbeatRollupState.current_for(user))
    assert_equal({ "7-18" => 60 }, snapshot[:coding_rhythm][:duration_by_slot])
  end

  test "excludes archived projects" do
    travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
      user = create(:user)
      create_heartbeat(user, "2026-04-14 09:00:00 UTC", project: "active", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      create_heartbeat(user, "2026-04-14 09:01:00 UTC", project: "active", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      create_heartbeat(user, "2026-04-14 10:00:00 UTC", project: "archived", language: "python", editor: "zed", operating_system: "linux", category: "coding")
      create_heartbeat(user, "2026-04-14 10:01:00 UTC", project: "archived", language: "python", editor: "zed", operating_system: "linux", category: "coding")
      create_heartbeat(user, "2026-04-14 11:00:00 UTC", project: nil, language: "go", editor: "vim", operating_system: "linux", category: "coding")
      create(:project_repo_mapping, user: user, project_name: "archived").archive!

      HeartbeatRollup.rebuild!(user)
      snapshot = HeartbeatRollup.dashboard_snapshot(HeartbeatRollupState.current_for(user))

      assert_equal 180, snapshot[:total_time]
      assert_equal 3, snapshot[:total_heartbeats]
      assert_equal [ "active" ], snapshot[:filter_options][:project]
      assert_equal [ "go", "ruby" ], snapshot[:filter_options][:language]
      assert_equal 180, snapshot[:today_stats][:todays_duration_seconds]
      assert_equal({ "active" => 60 }, snapshot[:grouped_durations][:project])
      assert_equal [ "active" ], snapshot[:project_details].keys
    end
  end

  test "a rebuild publishes a new generation and removes older ones" do
    user = create(:user)
    create_heartbeat(user, "2026-04-14 09:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
    create_heartbeat(user, "2026-04-14 09:01:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

    assert HeartbeatRollup.rebuild!(user)
    first_generation = HeartbeatRollupState.find_by!(user:).generation
    create_heartbeat(user, "2026-04-14 09:02:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
    assert HeartbeatRollup.rebuild!(user)

    state = HeartbeatRollupState.find_by!(user:)
    assert_operator state.generation, :>, first_generation
    assert_equal [ state.generation ], HeartbeatRollup.where(user_id: user.id).distinct.pluck(:generation)
    assert_equal 120, HeartbeatRollup.dashboard_snapshot(state)[:total_time]
  end

  test "a generation older than the published one is discarded" do
    user = create(:user)
    create_heartbeat(user, "2026-04-14 09:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
    newer = Process.clock_gettime(Process::CLOCK_REALTIME, :microsecond) + 60_000_000
    HeartbeatRollupState.publish!(user_id: user.id, generation: newer, timezone: user.timezone, heartbeat_cache_version: user.heartbeat_cache_version)

    assert_not HeartbeatRollup.rebuild!(user)
    assert_equal newer, HeartbeatRollupState.find_by!(user:).generation
    assert_equal 0, HeartbeatRollup.where(user_id: user.id).count
  end

  test "a rollup built for another timezone or exclusion set is not current" do
    user = create(:user, timezone: "UTC")
    HeartbeatRollup.rebuild!(user)
    assert HeartbeatRollupState.current_for(user)

    user.update!(timezone: "Europe/London")
    assert_nil HeartbeatRollupState.current_for(user)

    user.update!(timezone: "UTC")
    HeartbeatExclusion.create!(user:, kind: :project_deletion, project: "secret")
    assert_nil HeartbeatRollupState.current_for(User.find(user.id))
  end

  private

  def create_heartbeat(user, timestamp, project:, language:, editor:, operating_system:, category:)
    create(:heartbeat, user:, time: Time.parse(timestamp).to_f, project:, language:, editor:,
      operating_system:, category:, source_type: :test_entry)
  end
end
