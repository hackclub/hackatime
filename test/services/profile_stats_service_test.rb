require "test_helper"

class ProfileStatsServiceTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  test "dashboard_stats returns dashboard-shaped data backed by rollups" do
    user = User.create!(timezone: "UTC")
    base_time = (Time.current - 1.day).to_f

    create_heartbeat(user, time: base_time, project: "alpha", language: "Ruby", editor: "vscode")
    create_heartbeat(user, time: base_time + 60, project: "alpha", language: "Ruby", editor: "vscode")
    create_heartbeat(user, time: base_time + 120, project: "beta", language: "Python", editor: "vscode")

    DashboardRollupRefreshService.new(user: user).call

    payload = ProfileStatsService.new(user).dashboard_stats

    assert payload[:filterable_dashboard_data].present?
    assert_equal 120, payload[:filterable_dashboard_data][:total_time]
    assert payload[:activity_graph][:duration_by_date].is_a?(Hash)
    assert payload[:today_stats].key?(:show_logged_time_sentence)
  end

  test "og_stats reports totals and top language from rollups" do
    user = User.create!(timezone: "UTC")
    base_time = (Time.current - 1.hour).to_f

    create_heartbeat(user, time: base_time, project: "alpha", language: "Ruby", editor: "vscode")
    create_heartbeat(user, time: base_time + 60, project: "alpha", language: "Ruby", editor: "vscode")

    DashboardRollupRefreshService.new(user: user).call

    og = ProfileStatsService.new(user).og_stats

    assert_equal 60, og[:total_time_all]
    assert og[:total_time_week] >= 60
    assert_equal "Ruby", og[:top_language]
  end

  private

  def create_heartbeat(user, time:, project:, language: "Ruby", editor: "vscode")
    user.heartbeats.create!(
      entity: "src/main.rb",
      type: "file",
      category: "coding",
      editor: editor,
      language: language,
      time: time,
      project: project,
      source_type: :test_entry
    )
  end
end
