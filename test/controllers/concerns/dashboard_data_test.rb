require "test_helper"

class DashboardDataTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  class Harness
    include DashboardData

    attr_accessor :current_user, :params
  end

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
      harness = Harness.new
      harness.current_user = user
      harness.params = ActionController::Parameters.new

      create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

      first = harness.send(:dashboard_live_raw_filter_options)

      create_heartbeat(user, project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "browsing")

      second = harness.send(:dashboard_live_raw_filter_options)

      assert_equal [ "alpha" ], first.fetch(:project)
      assert_equal [ "alpha" ], second.fetch(:project)
      assert_equal [ "ruby" ], second.fetch(:language)
    end
  end

  test "project grouped durations preserve nil project values" do
    user = User.create!(timezone: "UTC")
    harness = Harness.new
    harness.current_user = user
    harness.params = ActionController::Parameters.new

    Heartbeat.create!(
      user: user,
      time: Time.current.to_f - 60,
      project: nil,
      language: "ruby",
      editor: "vscode",
      operating_system: "macos",
      category: "coding",
      source_type: :test_entry
    )
    Heartbeat.create!(
      user: user,
      time: Time.current.to_f,
      project: nil,
      language: "ruby",
      editor: "vscode",
      operating_system: "macos",
      category: "coding",
      source_type: :test_entry
    )
    create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
    create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

    scope = user.heartbeats

    assert_equal scope.group(:project).duration_seconds, harness.send(:dashboard_project_grouped_durations, scope)
  end

  test "all-time dashboard data can be served from rollups" do
    with_memory_cache_store do
      Rails.cache.clear

      user = User.create!(timezone: "UTC")
      harness = Harness.new
      harness.current_user = user
      harness.params = ActionController::Parameters.new

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        travel 1.minute
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        travel 1.minute
        create_heartbeat(user, project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "coding")
      end

      DashboardRollupRefreshService.new(user: user).call

      def harness.dashboard_grouped_durations_snapshot(_scope)
        raise "expected rollup-backed dashboard path"
      end

      def harness.dashboard_live_raw_filter_options
        raise "expected rollup-backed filter options path"
      end

      result = harness.send(:filterable_dashboard_data)

      assert_equal user.heartbeats.duration_seconds, result[:total_time]
      assert_equal user.heartbeats.count, result[:total_heartbeats]
      assert_equal "alpha", result["top_project"]
      assert_equal [ "alpha", "beta" ], result[:project]
    end
  end

  test "all-time dashboard data falls back when rollup table is unavailable" do
    with_memory_cache_store do
      Rails.cache.clear

      user = User.create!(timezone: "UTC")
      harness = Harness.new
      harness.current_user = user
      harness.params = ActionController::Parameters.new

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        travel 1.minute
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      end

      def harness.dashboard_rollups_available?
        false
      end

      result = harness.send(:filterable_dashboard_data)

      assert_equal user.heartbeats.duration_seconds, result[:total_time]
      assert_equal "alpha", result["top_project"]
    end
  end

  test "homepage rollup path falls back to live filter options when filter option rollup is missing" do
    with_memory_cache_store do
      Rails.cache.clear

      user = User.create!(timezone: "UTC")
      harness = build_harness(user)

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        travel 1.minute
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      end

      DashboardRollupRefreshService.new(user: user).call
      DashboardRollup.find_by!(user: user, dimension: DashboardRollup::FILTER_OPTIONS_DIMENSION).destroy!

      clear_enqueued_jobs
      Rails.cache.delete(DashboardRollupRefreshJob.enqueue_cache_key(user.id))

      result = nil
      assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ]) do
        result = harness.send(:filterable_dashboard_data)
      end

      assert_equal [ "alpha" ], result[:project]
      assert_equal [ "Ruby" ], result[:language]
    end
  end

  test "dirty rollup serves last rollup and schedules a refresh" do
    with_memory_cache_store do
      Rails.cache.clear

      user = User.create!(timezone: "UTC")
      harness = Harness.new
      harness.current_user = user
      harness.params = ActionController::Parameters.new

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        travel 1.minute
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      end

      DashboardRollupRefreshService.new(user: user).call

      def harness.dashboard_grouped_durations_snapshot(_scope)
        raise "expected rollup-backed dashboard path"
      end

      total_row = DashboardRollup.find_by!(user: user, dimension: DashboardRollup::TOTAL_DIMENSION)

      clear_enqueued_jobs
      travel 1.minute do
        create_heartbeat(user, project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "coding")
      end

      result = nil
      assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ])
      assert_no_enqueued_jobs(only: DashboardRollupRefreshJob) do
        result = harness.send(:filterable_dashboard_data)
      end

      assert_equal total_row.total_seconds, result[:total_time]
      assert_equal total_row.source_heartbeats_count, result[:total_heartbeats]
      assert_equal "alpha", result["top_project"]
      assert_equal [ "alpha" ], result[:project]
    end
  end

  test "stale rollup fingerprint serves last rollup and schedules a refresh" do
    with_memory_cache_store do
      Rails.cache.clear

      user = User.create!(timezone: "UTC")
      harness = Harness.new
      harness.current_user = user
      harness.params = ActionController::Parameters.new

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        travel 1.minute
        create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      end

      DashboardRollupRefreshService.new(user: user).call

      def harness.dashboard_grouped_durations_snapshot(_scope)
        raise "expected rollup-backed dashboard path"
      end

      total_row = DashboardRollup.find_by!(user: user, dimension: DashboardRollup::TOTAL_DIMENSION)

      travel 1.minute do
        create_heartbeat(user, project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "coding")
      end

      DashboardRollup.clear_dirty(user.id)
      Rails.cache.delete(DashboardRollupRefreshJob.enqueue_cache_key(user.id))

      result = nil
      assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ]) do
        result = harness.send(:filterable_dashboard_data)
      end

      assert_equal total_row.total_seconds, result[:total_time]
      assert_equal total_row.source_heartbeats_count, result[:total_heartbeats]
      assert_equal "alpha", result["top_project"]
      assert_equal [ "alpha" ], result[:project]
    end
  end

  test "today stats and activity graph can be served from rollups" do
    with_memory_cache_store do
      Rails.cache.clear

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        user = User.create!(timezone: "UTC")
        harness = build_harness(user)

        create_heartbeat_at(user, "2026-04-14 09:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-14 09:01:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-14 09:02:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

        DashboardRollupRefreshService.new(user: user).call

        def harness.dashboard_live_today_stats_data
          raise "expected rollup-backed today stats path"
        end

        def harness.dashboard_live_activity_graph_data
          raise "expected rollup-backed activity graph path"
        end

        today_stats = harness.send(:today_stats_data)
        activity_graph = harness.send(:activity_graph_data)

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

  test "invalid today stats rollup recalculates only today stats and schedules a refresh" do
    with_memory_cache_store do
      Rails.cache.clear

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        user = User.create!(timezone: "UTC")
        harness = build_harness(user)

        create_heartbeat_at(user, "2026-04-14 09:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-14 09:01:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-14 09:02:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

        DashboardRollupRefreshService.new(user: user).call

        today_row = DashboardRollup.find_by!(user: user, dimension: DashboardRollup::TODAY_STATS_DIMENSION)
        today_row.update!(payload: today_row.payload.merge("today_date" => "2026-04-13"))

        def harness.dashboard_grouped_durations_snapshot(_scope)
          raise "expected rollup-backed dashboard path"
        end

        def harness.dashboard_live_today_stats_data
          { source: :live_today }
        end

        def harness.dashboard_live_activity_graph_data
          raise "expected rollup-backed activity graph path"
        end

        clear_enqueued_jobs
        Rails.cache.delete(DashboardRollupRefreshJob.enqueue_cache_key(user.id))

        aggregate = nil
        today_stats = nil
        activity_graph = nil

        assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ]) do
          aggregate = harness.send(:filterable_dashboard_data)
          today_stats = harness.send(:today_stats_data)
          activity_graph = harness.send(:activity_graph_data)
        end

        assert_equal 120, aggregate[:total_time]
        assert_equal({ source: :live_today }, today_stats)
        assert_equal 120, activity_graph[:duration_by_date]["2026-04-14"]
        assert_equal 1, enqueued_jobs.count { |job| job[:job] == DashboardRollupRefreshJob }
      end
    end
  end

  test "invalid activity graph rollup recalculates only activity graph and schedules a refresh" do
    with_memory_cache_store do
      Rails.cache.clear

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        user = User.create!(timezone: "UTC")
        harness = build_harness(user)

        create_heartbeat_at(user, "2026-04-14 09:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-14 09:01:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-14 09:02:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

        DashboardRollupRefreshService.new(user: user).call

        activity_row = DashboardRollup.find_by!(user: user, dimension: DashboardRollup::ACTIVITY_GRAPH_DIMENSION)
        activity_row.update!(payload: activity_row.payload.merge("end_date" => "2026-04-13"))

        def harness.dashboard_grouped_durations_snapshot(_scope)
          raise "expected rollup-backed dashboard path"
        end

        def harness.dashboard_live_today_stats_data
          raise "expected rollup-backed today stats path"
        end

        def harness.dashboard_live_activity_graph_data
          { source: :live_activity }
        end

        clear_enqueued_jobs
        Rails.cache.delete(DashboardRollupRefreshJob.enqueue_cache_key(user.id))

        aggregate = nil
        today_stats = nil
        activity_graph = nil

        assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ]) do
          aggregate = harness.send(:filterable_dashboard_data)
          today_stats = harness.send(:today_stats_data)
          activity_graph = harness.send(:activity_graph_data)
        end

        assert_equal 120, aggregate[:total_time]
        assert today_stats[:show_logged_time_sentence]
        assert_equal({ source: :live_activity }, activity_graph)
        assert_equal 1, enqueued_jobs.count { |job| job[:job] == DashboardRollupRefreshJob }
      end
    end
  end

  test "missing today stats and activity graph rollups recalculate only those fragments and schedule one refresh" do
    with_memory_cache_store do
      Rails.cache.clear

      travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
        user = User.create!(timezone: "UTC")
        harness = build_harness(user)

        create_heartbeat_at(user, "2026-04-14 09:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-14 09:01:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
        create_heartbeat_at(user, "2026-04-14 09:02:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

        DashboardRollupRefreshService.new(user: user).call
        DashboardRollup.where(
          user: user,
          dimension: [ DashboardRollup::TODAY_STATS_DIMENSION, DashboardRollup::ACTIVITY_GRAPH_DIMENSION ]
        ).delete_all

        def harness.dashboard_grouped_durations_snapshot(_scope)
          raise "expected rollup-backed dashboard path"
        end

        def harness.dashboard_live_today_stats_data
          { source: :live_today }
        end

        def harness.dashboard_live_activity_graph_data
          { source: :live_activity }
        end

        clear_enqueued_jobs
        Rails.cache.delete(DashboardRollupRefreshJob.enqueue_cache_key(user.id))

        aggregate = nil
        today_stats = nil
        activity_graph = nil

        assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ]) do
          aggregate = harness.send(:filterable_dashboard_data)
          today_stats = harness.send(:today_stats_data)
          activity_graph = harness.send(:activity_graph_data)
        end

        assert_equal 120, aggregate[:total_time]
        assert_equal({ source: :live_today }, today_stats)
        assert_equal({ source: :live_activity }, activity_graph)
        assert_equal 1, enqueued_jobs.count { |job| job[:job] == DashboardRollupRefreshJob }
      end
    end
  end

  private

  def build_harness(user, params: {})
    harness = Harness.new
    harness.current_user = user
    harness.params = ActionController::Parameters.new(params)
    harness
  end

  def with_memory_cache_store
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache.lookup_store(:memory_store)
    yield
  ensure
    Rails.cache = original_cache
  end

  def create_heartbeat(user, project:, language:, editor:, operating_system:, category:)
    Heartbeat.create!(
      user: user,
      time: Time.current.to_f,
      project: project,
      language: language,
      editor: editor,
      operating_system: operating_system,
      category: category,
      source_type: :test_entry
    )
  end

  def create_heartbeat_at(user, timestamp, project:, language:, editor:, operating_system:, category:)
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
