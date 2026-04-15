require "test_helper"

class StaticPagesControllerTest < ActionDispatch::IntegrationTest
  test "signed in homepage dashboard stats preserves grouped durations and weekly project stats" do
    travel_to Time.utc(2026, 4, 14, 12, 0, 0) do
      user = User.create!(timezone: "UTC")
      sign_in_as(user)

      create_heartbeat(user, "2026-04-07 09:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      create_heartbeat(user, "2026-04-07 09:01:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      create_heartbeat(user, "2026-04-13 10:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      create_heartbeat(user, "2026-04-13 10:01:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
      create_heartbeat(user, "2026-04-13 10:03:00 UTC", project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "coding")
      create_heartbeat(user, "2026-04-13 10:05:00 UTC", project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "browsing")

      get root_path

      assert_response :success
      assert_inertia_component "Home/SignedIn"
      assert_equal [ "dashboard_stats" ], inertia_page.dig("deferredProps", "default")

      get root_path, headers: {
        "X-Inertia" => "true",
        "X-Requested-With" => "XMLHttpRequest",
        "X-Inertia-Version" => inertia_page["version"],
        "X-Inertia-Partial-Component" => "Home/SignedIn",
        "X-Inertia-Partial-Data" => "dashboard_stats"
      }

      assert_response :success

      page = JSON.parse(response.body)
      stats = page.dig("props", "dashboard_stats", "filterable_dashboard_data")

      assert_equal 480, stats["total_time"]
      assert_equal 6, stats["total_heartbeats"]
      assert_equal "alpha", stats["top_project"]

      assert_equal(
        {
          "alpha" => 240,
          "beta" => 120
        },
        stats["project_durations"]
      )

      assert_equal(
        {
          "2026-04-13" => {
            "alpha" => 60,
            "beta" => 120
          },
          "2026-04-06" => {
            "alpha" => 60
          }
        },
        stats["weekly_project_stats"].slice("2026-04-13", "2026-04-06")
      )
    end
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
