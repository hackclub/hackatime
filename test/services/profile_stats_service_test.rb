require "test_helper"

class ProfileStatsServiceTest < ActiveSupport::TestCase
  test "normalizes editor aliases before trimming to the top three" do
    user = User.create!(timezone: "UTC")
    service = ProfileStatsService.new(user)

    stubbed_response = {
      "today_seconds" => 0,
      "week_seconds" => 0,
      "all_seconds" => 0,
      "top_languages" => {},
      "top_projects" => {},
      "top_projects_month" => [],
      "top_editors" => {
        "vscode" => 120,
        "VSCode" => 90,
        "zed" => 60,
        "cursor" => 30
      }
    }

    original_profile_stats = StatsClient.method(:profile_stats)
    StatsClient.singleton_class.send(:define_method, :profile_stats) do |**_args|
      stubbed_response
    end

    stats = begin
      service.send(:compute_stats)
    ensure
      StatsClient.singleton_class.send(:define_method, :profile_stats, original_profile_stats)
    end

    assert_equal(
      {
        "VS Code" => 210,
        "Zed" => 60,
        "Cursor" => 30
      },
      stats[:top_editors]
    )
  end
end
