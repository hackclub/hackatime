require "test_helper"

class ProfileStatsServiceTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
    @original_timeout = Heartbeat.heartbeat_timeout_duration
    Heartbeat.heartbeat_timeout_duration(1.second)
  end

  teardown do
    Heartbeat.heartbeat_timeout_duration(@original_timeout)
    Rails.cache.clear
  end

  test "stats aggregates totals, month projects, and normalized editors in one payload" do
    travel_to Time.utc(2026, 1, 14, 12, 0, 0) do
      user = User.create!(timezone: "UTC")
      mapping = user.project_repo_mappings.create!(project_name: "alpha")
      mapping.update_column(:repo_url, "https://github.com/hackclub/alpha")

      create_heartbeat_pair(user, Time.utc(2026, 1, 14, 9, 0, 0), language: "Ruby", project: "alpha", editor: "vscode")
      create_heartbeat_pair(user, Time.utc(2026, 1, 14, 10, 0, 0), language: "Ruby", project: "alpha", editor: "vs code")
      create_heartbeat_pair(user, Time.utc(2026, 1, 12, 8, 0, 0), language: "Python", project: "beta", editor: "pycharm")
      create_heartbeat_pair(user, Time.utc(2025, 12, 1, 8, 0, 0), language: "Go", project: "gamma", editor: "rubymine")

      stats = ProfileStatsService.new(user).stats

      assert_equal 4, stats[:total_time_today]
      assert_equal 6, stats[:total_time_week]
      assert_equal 7, stats[:total_time_all]
      assert_equal({ "Ruby" => 4, "Python" => 2, "Go" => 1 }, stats[:top_languages])
      assert_equal({ "alpha" => 4, "beta" => 2, "gamma" => 1 }, stats[:top_projects])
      assert_equal(
        {
          "VS Code" => 4,
          "PyCharm" => 2,
          "RubyMine" => 1
        },
        stats[:top_editors]
      )

      assert_equal [
        { project: "alpha", duration: 4, repo_url: "https://github.com/hackclub/alpha" },
        { project: "beta", duration: 2, repo_url: nil }
      ], stats[:top_projects_month]
    end
  end

  private

  def create_heartbeat_pair(user, started_at, language:, project:, editor:)
    user.heartbeats.create!(
      category: "coding",
      language: language,
      project: project,
      editor: editor,
      time: started_at.to_f,
      source_type: :test_entry
    )
    user.heartbeats.create!(
      category: "coding",
      language: language,
      project: project,
      editor: editor,
      time: (started_at + 1.second).to_f,
      source_type: :test_entry
    )
  end
end
