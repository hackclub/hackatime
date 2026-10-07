require "test_helper"

class DashboardStatsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
  end

  teardown do
    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  test "raw filter options are cached per user" do
    with_memory_cache_store do
      Rails.cache.clear

      user = create(:user)
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
    user = create(:user)

    create(:heartbeat,
      user: user, time: Time.current.to_f - 60, project: nil,
      language: "ruby", editor: "vscode", operating_system: "macos",
      category: "coding", source_type: :test_entry
    )
    create(:heartbeat,
      user: user, time: Time.current.to_f, project: nil,
      language: "ruby", editor: "vscode", operating_system: "macos",
      category: "coding", source_type: :test_entry
    )
    create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
    create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

    scope = user.heartbeats

    snapshot = DashboardData::Snapshots.aggregate_query_snapshot(user:, scope:)
    assert_equal scope.group(:project).duration_seconds, snapshot[:grouped_durations][:project]
  end

  test "all-time dashboard data can be served from rollups" do
    with_memory_cache_store do
      Rails.cache.clear
      user = create(:user)

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        travel 1.minute
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        travel 1.minute
        create_heartbeat(user, project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "coding")
      end

      HeartbeatRollup.rebuild!(user)

      stats = build_stats(user)
      def stats.query_result(*) = raise("expected rollup-backed dashboard path")
      def stats.live_raw_filter_options = raise("expected rollup-backed filter options path")

      result = stats.filterable_dashboard_data

      assert_equal user.heartbeats.duration_seconds, result[:total_time]
      assert_equal user.heartbeats.count, result[:total_heartbeats]
      assert_equal "alpha", result["top_project"]
      assert_equal [ "alpha", "beta" ], result[:project]
    end
  end

  test "dashboard falls back to live data and schedules a rebuild when there is no current rollup" do
    with_memory_cache_store do
      Rails.cache.clear
      user = create(:user)

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        travel 1.minute
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      end
      clear_enqueued_jobs
      Rails.cache.delete(DashboardRollupRefreshJob.enqueue_cache_key(user.id))

      stats = build_stats(user)
      result = today_stats = activity_graph = nil
      assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ]) do
        result = stats.filterable_dashboard_data
        today_stats = stats.today_stats_data
        activity_graph = stats.activity_graph_data
      end

      assert_equal 1, enqueued_jobs.count { |job| job[:job] == DashboardRollupRefreshJob }
      assert_equal user.heartbeats.duration_seconds, result[:total_time]
      assert_equal "alpha", result["top_project"]
      assert_equal [ "Ruby" ], result[:language]
      assert_kind_of Hash, today_stats
      assert_equal 60, activity_graph[:duration_by_date]["2026-04-14"]
    end
  end

  test "selected periods include average coding time per elapsed day" do
    with_memory_cache_store do
      Rails.cache.clear
      user = create(:user)

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        create_heartbeat_at(user, "2026-04-13 09:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-13 09:01:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-14 09:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

        result = build_stats(user, params: { interval: "yesterday" }).filterable_dashboard_data

        assert_equal 60, result[:total_time]
        assert_equal(
          { average_seconds: 60.0, total_seconds: 60, day_count: 1, period_label: "Yesterday" },
          result[:coding_time_average]
        )

        this_month = build_stats(user, params: { interval: "this_month" }).coding_time_average(14.hours, "this_month")
        assert_equal 14, this_month[:day_count]
        assert_equal 1.hour, this_month[:average_seconds]
        assert_equal "This Month", this_month[:period_label]

        high_seas = build_stats(user).coding_time_average(94.hours, "high_seas")
        assert_equal 94, high_seas[:day_count]
        assert_equal 1.hour, high_seas[:average_seconds]
        assert_equal "High Seas", high_seas[:period_label]
      end
    end
  end

  test "until-only period average starts at first heartbeat matching dashboard filters" do
    with_memory_cache_store do
      Rails.cache.clear
      user = create(:user)

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        create_heartbeat_at(user, "2026-01-01 09:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-13 09:00:00 UTC", project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "coding")
        create_heartbeat_at(user, "2026-04-13 09:01:00 UTC", project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "coding")

        result = build_stats(
          user,
          params: { interval: "custom", to: "2026-04-14", project: "beta" }
        ).filterable_dashboard_data

        # The first beta row owns the capped gap from alpha, then adds 60s.
        assert_equal 180, result[:total_time]
        assert_equal 2, result.dig(:coding_time_average, :day_count)
        assert_equal 90.0, result.dig(:coding_time_average, :average_seconds)
      end
    end
  end

  test "language filters retain durations from the complete heartbeat timeline" do
    with_memory_cache_store do
      Rails.cache.clear
      user = create(:user)

      create_heartbeat_at(user, "2026-04-14 09:00:00 UTC", project: "alpha", language: "XML", editor: "vscode", operating_system: "macos", category: "coding")
      create_heartbeat_at(user, "2026-04-14 09:01:00 UTC", project: "beta", language: "Ruby", editor: "vscode", operating_system: "macos", category: "coding")
      create_heartbeat_at(user, "2026-04-14 09:02:00 UTC", project: "alpha", language: "XML", editor: "vscode", operating_system: "macos", category: "coding")

      stats = build_stats(user, params: { language: "XML" })

      result = stats.filterable_dashboard_data

      assert_equal 60, result[:total_time]
      assert_equal({ "alpha" => 60 }, result[:project_durations])
    end
  end

  test "combined filters sum attributed rows consistently across every dashboard aggregate" do
    user = create(:user, timezone: "UTC")
    travel_to Time.utc(2026, 4, 14, 12) do
      attributes = { project: "alpha", language: "XML", editor: "vscode", operating_system: "macos", category: "coding" }
      create_heartbeat_at(user, "2026-04-13 23:59:30 UTC", **attributes)
      create_heartbeat_at(user, "2026-04-14 09:00:00 UTC", **attributes)
      create_heartbeat_at(user, "2026-04-14 09:01:00 UTC", **attributes.merge(project: "beta", language: "Ruby"))
      create_heartbeat_at(user, "2026-04-14 09:02:00 UTC", **attributes)
      create_heartbeat_at(user, "2026-04-14 09:03:00 UTC", **attributes.merge(editor: "zed"))
      create_heartbeat_at(user, "2026-04-14 09:04:00 UTC", **attributes.merge(project: "gamma", language: "JSON"))
      create_heartbeat_at(user, "2026-04-14 09:10:00 UTC", **attributes.merge(project: "gamma", language: "JSON"))

      stats = build_stats(user, params: {
        interval: "today", project: "alpha,gamma", language: "XML,JSON",
        editor: "VSCode", operating_system: "macOS", category: "coding"
      })
      result = stats.build_filterable_dashboard_data("today")

      assert_equal 240, result[:total_time]
      assert_equal 4, result[:total_heartbeats]
      assert_equal({ "alpha" => 60, "gamma" => 180 }, result[:project_durations])
      assert_equal({ "XML" => 60, "JSON" => 180 }, result["language_stats"])
      assert_equal({ "coding" => 240 }, result[:coding_category_stats])
      assert_equal({ "alpha" => 60, "gamma" => 180 }, result[:weekly_project_stats].fetch("2026-04-13"))
      assert_equal({ "2-9" => 240 }, result[:coding_rhythm][:duration_by_slot])
    end
  end

  test "filtered duration timeline excludes archived deleted and other users heartbeats" do
    user = create(:user)
    attributes = { project: "alpha", language: "XML", editor: "vscode", operating_system: "macos", category: "coding" }
    create_heartbeat_at(user, "2026-04-14 09:00:00 UTC", **attributes)
    create_heartbeat_at(user, "2026-04-14 09:01:00 UTC", **attributes.merge(project: "archived"))
    create(:project_repo_mapping, user: user, project_name: "archived").archive!
    deleted = create_heartbeat_at(user, "2026-04-14 09:01:30 UTC", **attributes)
    deleted.soft_delete
    create_heartbeat_at(create(:user), "2026-04-14 09:01:45 UTC", **attributes)
    create_heartbeat_at(user, "2026-04-14 09:02:00 UTC", **attributes)

    result = build_stats(user, params: { language: "XML" }).build_filterable_dashboard_data(nil)
    assert_equal 120, result[:total_time]
    assert_equal 2, result[:total_heartbeats]
    assert_equal({ "alpha" => 120 }, result[:project_durations])

    empty = build_stats(user, params: { language: "Ruby" }).build_filterable_dashboard_data(nil)
    assert_equal 0, empty[:total_time]
    assert_equal 0, empty[:total_heartbeats]
    assert_empty empty[:project_durations]
    assert_empty empty[:coding_rhythm][:duration_by_slot]
  end

  test "small and large filtered timelines preserve duration attribution" do
    [ 3, 1_002 ].each do |heartbeat_count|
      user = create(:user, timezone: "UTC")
      first = create(
        :heartbeat,
        user: user,
        time: Time.utc(2026, 4, 14, 9).to_f,
        project: "alpha",
        language: "XML",
        editor: "vscode",
        operating_system: "macos",
        category: "coding"
      )
      Heartbeat.insert_rows!((1...heartbeat_count).map do |offset|
        Heartbeat.row_for_insert(first.attributes.except("id").merge(
          "time" => first.time + offset,
          "language" => offset == 1 ? "Ruby" : "XML"
        ))
      end, sync: true)

      result = build_stats(user, params: { language: "XML" }).filterable_dashboard_data

      assert_equal heartbeat_count - 2, result[:total_time]
      assert_equal heartbeat_count - 1, result[:total_heartbeats]
      assert_equal({ "alpha" => heartbeat_count - 2 }, result[:project_durations])
      assert_equal heartbeat_count - 2, result[:coding_category_stats].values.sum
      assert_equal heartbeat_count - 2, result[:coding_rhythm][:duration_by_slot].values.sum
    end
  end

  test "filtered timelines preserve timestamp ties nil buckets and fractional durations" do
    user = create(:user, timezone: "Europe/London")
    time = Time.utc(2026, 4, 13, 22, 59, 59).to_f
    create(:heartbeat, user: user, time: time, language: "Ruby", project: "beta")
    create(:heartbeat, user: user, time: time + 1.5, language: "XML", project: nil)
    create(:heartbeat, user: user, time: time + 1.5, language: "Ruby", project: "beta")
    create(:heartbeat, user: user, time: time + 1.5, language: "XML", project: nil, entity: "other.xml")
    create(:heartbeat, user: user, time: time + 2.25, language: "XML", project: nil)
    actual = DashboardData::Snapshots.adaptive_filtered_snapshot(user: user, scope: user.heartbeats) { |scope| scope.where(language: "XML") }
    assert_equal 2, actual[:total_time]
    assert_equal({ nil => 2 }, actual[:grouped_durations][:project])
    assert_equal({ "2-0" => 2 }, actual[:coding_rhythm][:duration_by_slot])
  end

  test "new heartbeats keep serving the published rollup and schedule a rebuild" do
    with_memory_cache_store do
      Rails.cache.clear
      user = create(:user)

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        travel 1.minute
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      end

      HeartbeatRollup.rebuild!(user)
      clear_enqueued_jobs
      Rails.cache.delete(DashboardRollupRefreshJob.enqueue_cache_key(user.id))

      assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ]) do
        travel_to Time.utc(2026, 4, 14, 12, 2, 0) do
          create_heartbeat(user, project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "coding")
        end
      end

      stats = build_stats(user)
      def stats.query_result(*) = raise("expected rollup-backed dashboard path")

      result = stats.filterable_dashboard_data

      assert_equal 60, result[:total_time]
      assert_equal 2, result[:total_heartbeats]
      assert_equal "alpha", result["top_project"]
      assert_equal [ "alpha" ], result[:project]

      perform_enqueued_jobs(only: DashboardRollupRefreshJob)
      assert_equal 120, build_stats(user).filterable_dashboard_data[:total_time]
    end
  end

  test "today stats and activity graph can be served from rollups" do
    with_memory_cache_store do
      Rails.cache.clear

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        user = create(:user)
        create_heartbeat_at(user, "2026-04-14 09:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-14 09:01:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-14 09:02:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

        HeartbeatRollup.rebuild!(user)

        stats = build_stats(user)
        def stats.today_stats_snapshot(_scope) = raise("expected rollup-backed today stats path")
        def stats.live_activity_graph_data = raise("expected rollup-backed activity graph path")

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

  test "selecting a remapped operating_system filter value matches the underlying raw rows" do
    with_memory_cache_store do
      Rails.cache.clear

      user = create(:user)
      create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "Mac", category: "coding")
      create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "Mac", category: "coding")
      create_heartbeat(user, project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "coding")

      stats = build_stats(user, params: { operating_system: "macOS" })

      result = stats.filterable_dashboard_data

      assert_equal 2, result[:total_heartbeats]
      assert_equal "alpha", result["top_project"]
    end
  end

  test "dashboard aggregates and filter options exclude archived projects" do
    with_memory_cache_store do
      Rails.cache.clear

      user = create(:user)
      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        create_heartbeat_at(user, "2026-04-14 09:00:00 UTC", project: "active", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-14 09:01:00 UTC", project: "active", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-14 10:00:00 UTC", project: "archived", language: "python", editor: "zed", operating_system: "linux", category: "coding")
        create_heartbeat_at(user, "2026-04-14 10:01:00 UTC", project: "archived", language: "python", editor: "zed", operating_system: "linux", category: "coding")
      end
      create(:project_repo_mapping, user: user, project_name: "archived").archive!

      stats = build_stats(user, params: { interval: "custom", from: "2026-04-14", to: "2026-04-14" })

      result = stats.filterable_dashboard_data

      assert_equal 60, result[:total_time]
      assert_equal 2, result[:total_heartbeats]
      assert_equal [ "active" ], result[:project]
      assert_equal [ "Ruby" ], result[:language]
      assert_equal "active", result["top_project"]
      assert_equal "Ruby", result["top_language"]
    end
  end

  test "coding category meter data remains available for a singular category filter" do
    with_memory_cache_store do
      Rails.cache.clear
      user = create(:user)
      create_heartbeat_at(user, "2026-04-14 09:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "ai coding")
      create_heartbeat_at(user, "2026-04-14 09:01:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "ai coding")

      stats = build_stats(user, params: { category: "ai coding" })

      result = stats.filterable_dashboard_data

      assert_equal true, result["singular_category"]
      assert_nil result["category_stats"]
      assert_equal({ "ai coding" => 60 }, result[:coding_category_stats])
    end
  end

  test "top operating system uses the same display buckets as operating system stats" do
    with_memory_cache_store do
      Rails.cache.clear

      user = create(:user)
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

      HeartbeatRollup.rebuild!(user)
      result = build_stats(user).filterable_dashboard_data

      assert_equal "Linux", result["operating_system_stats"].keys.first
      assert_equal "Linux", result["top_operating_system"]
    end
  end

  test "dashboard hides broken project names from project summaries" do
    with_memory_cache_store do
      Rails.cache.clear

      # Freeze time for the whole test so weekly rollups use the same week as the heartbeats.
      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        user = create(:user)
        [ "<<LAST_PROJECT>>", "", nil, "Unknown" ].each_with_index do |project, index|
          start_at = Time.zone.parse("2026-04-13 09:00:00") + index.hours
          create_heartbeat_at(user, start_at.to_s, project:, language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
          create_heartbeat_at(user, (start_at + 2.minutes).to_s, project:, language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        end

        create_heartbeat_at(user, "2026-04-13 14:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-13 14:01:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

        HeartbeatRollup.rebuild!(user)
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

      user = create(:user)
      create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      create_heartbeat(user, project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "coding")

      stats = build_stats(user, params: { editor: "VSCode" })

      result = stats.filterable_dashboard_data

      assert_equal 2, result[:total_heartbeats]
      assert_equal "alpha", result["top_project"]
    end
  end

  test "a rollup built for another timezone is ignored and schedules one refresh" do
    with_memory_cache_store do
      Rails.cache.clear

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        user = create(:user)
        create_heartbeat_at(user, "2026-04-14 09:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-14 09:01:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-14 09:02:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

        HeartbeatRollup.rebuild!(user)
        user.update_column(:timezone, "Asia/Tokyo")

        stats = build_stats(user)
        def stats.live_raw_filter_options = { project: [ "alpha" ], language: [ "ruby" ], editor: [], operating_system: [], category: [] }

        clear_enqueued_jobs
        Rails.cache.delete(DashboardRollupRefreshJob.enqueue_cache_key(user.id))

        aggregate = today_stats = activity_graph = nil
        assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ]) do
          aggregate = stats.filterable_dashboard_data
          today_stats = stats.today_stats_data
          activity_graph = stats.activity_graph_data
        end

        assert_equal 120, aggregate[:total_time]
        assert today_stats[:show_logged_time_sentence]
        assert_equal [ ApplicationController.helpers.display_language_name("ruby") ], today_stats[:todays_languages]
        assert_equal 120, activity_graph[:duration_by_date]["2026-04-14"]
        assert_equal 1, enqueued_jobs.count { |job| job[:job] == DashboardRollupRefreshJob }
      end
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
    create(:heartbeat,
      user: user, time: Time.current.to_f, project: project,
      language: language, editor: editor, operating_system: operating_system,
      category: category, source_type: :test_entry
    )
  end

  def create_heartbeat_at(user, timestamp, project:, language:, editor:, operating_system:, category:)
    create(:heartbeat,
      user: user, time: Time.parse(timestamp).to_f, project: project,
      language: language, editor: editor, operating_system: operating_system,
      category: category, source_type: :test_entry
    )
  end
end
