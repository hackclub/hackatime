require "test_helper"

class DashboardSnapshotTest < ActiveSupport::TestCase
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
      user = User.create!(timezone: "UTC")

      create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      first = DashboardSnapshot.new(user: user, params: { interval: "week" }).call

      create_heartbeat(user, project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "browsing")
      second = DashboardSnapshot.new(user: user, params: { interval: "week" }).call

      assert_equal [ "alpha" ], first.filterable_dashboard_data.fetch(:project)
      assert_equal [ "alpha" ], second.filterable_dashboard_data.fetch(:project)
      assert_equal [ "Ruby" ], second.filterable_dashboard_data.fetch(:language)
    end
  end

  test "all-time dashboard data can be served from rollups with source metadata" do
    with_memory_cache_store do
      Rails.cache.clear
      user = User.create!(timezone: "UTC")

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        travel 1.minute
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        travel 1.minute
        create_heartbeat(user, project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "coding")
      end

      DashboardSnapshot.new(user: user).persist_rollups!
      result = DashboardSnapshot.new(user: user).call

      assert_equal user.heartbeats.duration_seconds, result.filterable_dashboard_data[:total_time]
      assert_equal user.heartbeats.count, result.filterable_dashboard_data[:total_heartbeats]
      assert_equal "alpha", result.filterable_dashboard_data["top_project"]
      assert_equal [ "alpha", "beta" ], result.filterable_dashboard_data[:project]
      assert_equal :rollup, result.sources[:aggregate]
      assert_equal :rollup, result.sources[:filter_options]
    end
  end

  test "dirty rollup serves last rollup and schedules a refresh" do
    with_memory_cache_store do
      Rails.cache.clear
      user = User.create!(timezone: "UTC")

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        travel 1.minute
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      end

      DashboardSnapshot.new(user: user).persist_rollups!
      total_row = DashboardRollup.find_by!(user: user, dimension: DashboardRollup::TOTAL_DIMENSION)

      clear_enqueued_jobs
      Rails.cache.delete(DashboardRollupRefreshJob.enqueue_cache_key(user.id))
      travel 1.minute do
        create_heartbeat(user, project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "coding")
      end
      clear_enqueued_jobs
      Rails.cache.delete(DashboardRollupRefreshJob.enqueue_cache_key(user.id))

      result = nil
      assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ]) do
        result = DashboardSnapshot.new(user: user).call
      end

      assert_equal total_row.total_seconds, result.filterable_dashboard_data[:total_time]
      assert_equal total_row.source_heartbeats_count, result.filterable_dashboard_data[:total_heartbeats]
      assert_equal "alpha", result.filterable_dashboard_data["top_project"]
      assert_equal :stale_rollup, result.sources[:aggregate]
      assert_equal 1, enqueued_jobs.count { |job| job[:job] == DashboardRollupRefreshJob }
    end
  end

  test "today stats and activity graph can be served from rollups" do
    with_memory_cache_store do
      Rails.cache.clear

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        user = User.create!(timezone: "UTC")
        create_heartbeat_at(user, "2026-04-14 09:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-14 09:01:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-14 09:02:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

        DashboardSnapshot.new(user: user).persist_rollups!
        result = DashboardSnapshot.new(user: user).call

        assert result.today_stats[:show_logged_time_sentence]
        assert_equal [ ApplicationController.helpers.display_language_name("ruby") ], result.today_stats[:todays_languages]
        assert_equal [ ApplicationController.helpers.display_editor_name("vscode") ], result.today_stats[:todays_editors]
        assert_equal ApplicationController.helpers.short_time_detailed(120), result.today_stats[:todays_duration_display]
        assert_equal "2025-04-14", result.activity_graph[:start_date]
        assert_equal "2026-04-14", result.activity_graph[:end_date]
        assert_equal 120, result.activity_graph[:duration_by_date]["2026-04-14"]
        assert_equal :rollup, result.sources[:today_stats]
        assert_equal :rollup, result.sources[:activity_graph]
      end
    end
  end

  test "invalid fragments recalculate only invalid fragments and schedule one refresh" do
    with_memory_cache_store do
      Rails.cache.clear

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        user = User.create!(timezone: "UTC")
        create_heartbeat_at(user, "2026-04-14 09:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-14 09:01:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-14 09:02:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

        DashboardSnapshot.new(user: user).persist_rollups!
        today_row = DashboardRollup.find_by!(user: user, dimension: DashboardRollup::TODAY_STATS_DIMENSION)
        today_row.update!(payload: today_row.payload.merge("today_date" => "2026-04-13"))
        activity_row = DashboardRollup.find_by!(user: user, dimension: DashboardRollup::ACTIVITY_GRAPH_DIMENSION)
        activity_row.update!(payload: activity_row.payload.merge("end_date" => "2026-04-13"))

        clear_enqueued_jobs
        Rails.cache.delete(DashboardRollupRefreshJob.enqueue_cache_key(user.id))

        result = nil
        assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ]) do
          result = DashboardSnapshot.new(user: user).call
        end

        assert_equal 120, result.filterable_dashboard_data[:total_time]
        assert_equal :rollup, result.sources[:aggregate]
        assert_equal :live, result.sources[:today_stats]
        assert_equal :live, result.sources[:activity_graph]
        assert_equal 1, enqueued_jobs.count { |job| job[:job] == DashboardRollupRefreshJob }
      end
    end
  end

  private

  def with_memory_cache_store
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache.lookup_store(:memory_store)
    yield
  ensure
    Rails.cache = original_cache
  end

  def create_heartbeat(user, project:, language:, editor:, operating_system:, category:)
    Heartbeat.create!(user: user, time: Time.current.to_f, project: project, language: language, editor: editor, operating_system: operating_system, category: category, source_type: :test_entry)
  end

  def create_heartbeat_at(user, timestamp, project:, language:, editor:, operating_system:, category:)
    Heartbeat.create!(user: user, time: Time.parse(timestamp).to_f, project: project, language: language, editor: editor, operating_system: operating_system, category: category, source_type: :test_entry)
  end
end
