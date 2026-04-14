require "test_helper"

class DashboardDataTest < ActiveSupport::TestCase
  class Harness
    include DashboardData

    attr_accessor :current_user, :params
  end

  test "raw filter options are cached per user" do
    with_memory_cache_store do
      Rails.cache.clear

      user = User.create!(timezone: "UTC")
      harness = Harness.new
      harness.current_user = user
      harness.params = ActionController::Parameters.new

      create_heartbeat(user, project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")

      first = harness.send(:dashboard_raw_filter_options)

      create_heartbeat(user, project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "browsing")

      second = harness.send(:dashboard_raw_filter_options)

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

  private

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
end
