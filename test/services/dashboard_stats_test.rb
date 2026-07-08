require "test_helper"

class DashboardStatsTest < ActiveSupport::TestCase
  test "raw filter options are cached per user" do
    with_memory_cache_store do
      Rails.cache.clear

      user = User.create!(timezone: "UTC")
      stats = build_stats(user)

      create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

      first = stats.live_raw_filter_options

      create_heartbeat(user, project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "browsing")

      second = stats.live_raw_filter_options

      assert_equal [ "alpha" ], first.fetch(:project)
      assert_equal [ "alpha" ], second.fetch(:project)
      assert_equal [ "ruby" ], second.fetch(:language)
    end
  end

  test "project grouped durations preserve nil project values" do
    user = User.create!(timezone: "UTC")
    stats = build_stats(user)

    Clickhouse::HeartbeatWriter.create!(
      user_id: user.id, time: Time.current.to_f - 60, project: nil,
      language: "ruby", editor: "vscode", operating_system: "macos",
      category: "coding", source_type: :test_entry
    )
    Clickhouse::HeartbeatWriter.create!(
      user_id: user.id, time: Time.current.to_f, project: nil,
      language: "ruby", editor: "vscode", operating_system: "macos",
      category: "coding", source_type: :test_entry
    )
    create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
    create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

    scope = Clickhouse::Heartbeat.for_user(user)

    assert_equal scope.group(:project).duration_seconds, stats.project_grouped_durations(scope)
  end

  test "all-time dashboard data aggregates live heartbeats" do
    with_memory_cache_store do
      Rails.cache.clear
      user = User.create!(timezone: "UTC")

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        travel 1.minute
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        travel 1.minute
        create_heartbeat(user, project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "coding")

        result = build_stats(user).filterable_dashboard_data

        assert_equal Clickhouse::Heartbeat.for_user(user).duration_seconds, result[:total_time]
        assert_equal Clickhouse::Heartbeat.for_user(user).count, result[:total_heartbeats]
        assert_equal "alpha", result["top_project"]
        assert_equal [ "alpha", "beta" ], result[:project]
      end
    end
  end

  test "today stats and activity graph are served live" do
    with_memory_cache_store do
      Rails.cache.clear

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        user = User.create!(timezone: "UTC")
        create_heartbeat_at(user, "2026-04-14 09:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-14 09:01:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-14 09:02:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

        stats = build_stats(user)
        today_stats = stats.today_stats_data
        activity_graph = stats.activity_graph_data

        assert today_stats[:show_logged_time_sentence]
        assert_equal [ ApplicationController.helpers.display_language_name("ruby") ], today_stats[:todays_languages]
        assert_equal [ ApplicationController.helpers.display_editor_name("vscode") ], today_stats[:todays_editors]
        assert_equal ApplicationController.helpers.short_time_detailed(120), today_stats[:todays_duration_display]
        assert_equal "2025-04-14", activity_graph[:start_date]
        assert_equal "2026-04-14", activity_graph[:end_date]
        assert_equal 120, activity_graph[:duration_by_date]["2026-04-14"]
      end
    end
  end

  test "unfiltered all-time dashboard data is cached" do
    with_memory_cache_store do
      Rails.cache.clear

      user = User.create!(timezone: "UTC")
      create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

      first = build_stats(user).filterable_dashboard_data

      create_heartbeat(user, project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "coding")

      second = build_stats(user).filterable_dashboard_data

      assert_equal first[:total_heartbeats], second[:total_heartbeats]
      assert_equal first[:project], second[:project]
    end
  end

  test "selecting a remapped operating_system filter value matches the underlying raw rows" do
    with_memory_cache_store do
      Rails.cache.clear

      user = User.create!(timezone: "UTC")
      create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "Mac", category: "coding")
      create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "Mac", category: "coding")
      create_heartbeat(user, project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "coding")

      stats = build_stats(user, params: { operating_system: "macOS" })

      result = stats.filterable_dashboard_data

      assert_equal 2, result[:total_heartbeats]
      assert_equal "alpha", result["top_project"]
    end
  end

  test "top operating system uses the same display buckets as operating system stats" do
    with_memory_cache_store do
      Rails.cache.clear

      user = User.create!(timezone: "UTC")
      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        %w[linux linux Linux Linux LINUX LINUX macos macos macos].each_with_index do |operating_system, index|
          create_heartbeat_at(
            user,
            (Time.current + index.minutes).to_s,
            project: "alpha",
            language: "ruby",
            editor: "vscode",
            operating_system: operating_system,
            category: "coding"
          )
        end
      end

      result = build_stats(user).filterable_dashboard_data

      assert_equal "Linux", result["operating_system_stats"].keys.first
      assert_equal "Linux", result["top_operating_system"]
    end
  end

  test "dashboard hides broken project names from project summaries" do
    with_memory_cache_store do
      Rails.cache.clear

      user = User.create!(timezone: "UTC")
      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        [ "<<LAST_PROJECT>>", "", nil, "Unknown" ].each_with_index do |project, index|
          start_at = Time.zone.parse("2026-04-13 09:00:00") + index.hours
          create_heartbeat_at(user, start_at.to_s, project:, language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
          create_heartbeat_at(user, (start_at + 2.minutes).to_s, project:, language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        end

        create_heartbeat_at(user, "2026-04-13 14:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-13 14:01:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

        result = build_stats(user).filterable_dashboard_data

        assert_equal "alpha", result["top_project"]
        assert_equal [ "alpha" ], result[:project]
        assert_equal({ "alpha" => 60 }, result[:project_durations])
        assert_equal({ "alpha" => 60 }, result[:weekly_project_stats].fetch("2026-04-13"))
      end
    end
  end

  test "selecting a remapped editor filter value matches the underlying raw rows" do
    with_memory_cache_store do
      Rails.cache.clear

      user = User.create!(timezone: "UTC")
      create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      create_heartbeat(user, project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "coding")

      stats = build_stats(user, params: { editor: "VSCode" })

      result = stats.filterable_dashboard_data

      assert_equal 2, result[:total_heartbeats]
      assert_equal "alpha", result["top_project"]
    end
  end

  private

  def build_stats(user, params: {})
    DashboardStats.new(user: user, params: ActionController::Parameters.new(params))
  end

  def with_memory_cache_store
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache.lookup_store(:memory_store)
    yield
  ensure
    Rails.cache = original_cache
  end

  def create_heartbeat(user, project:, language:, editor:, operating_system:, category:)
    Clickhouse::HeartbeatWriter.create!(
      user_id: user.id, time: Time.current.to_f, project: project,
      language: language, editor: editor, operating_system: operating_system,
      category: category, source_type: :test_entry
    )
  end

  def create_heartbeat_at(user, timestamp, project:, language:, editor:, operating_system:, category:)
    Clickhouse::HeartbeatWriter.create!(
      user_id: user.id, time: Time.parse(timestamp).to_f, project: project,
      language: language, editor: editor, operating_system: operating_system,
      category: category, source_type: :test_entry
    )
  end
end
