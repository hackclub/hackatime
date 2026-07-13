require "test_helper"

class My::ProjectRepoMappingsControllerTest < ActionDispatch::IntegrationTest
  test "index redirects guests" do
    get my_projects_path

    assert_response :redirect
    assert_redirected_to root_path
  end

  test "index defers project data when the user has heartbeats" do
    user = User.create!(timezone: "UTC")
    user.project_repo_mappings.create!(project_name: "alpha")
    create_project_heartbeats(user, "alpha")

    sign_in_as(user)
    get my_projects_path

    assert_response :success
    assert_inertia_component "Projects/Index"

    page = inertia_page
    assert_equal false, page.dig("props", "show_archived")
    assert_equal 1, page.dig("props", "total_projects")
    assert_equal [ "projects_data" ], page.dig("deferredProps", "default")
  end

  test "index still defers interval-filtered project data" do
    user = User.create!(timezone: "UTC")
    user.project_repo_mappings.create!(project_name: "alpha")
    create_project_heartbeats(user, "alpha")

    sign_in_as(user)
    get my_projects_path(interval: "last_7_days")

    assert_response :success

    page = inertia_page
    assert_equal [ "projects_data" ], page.dig("deferredProps", "default")
  end

  test "deferred all-time project list uses serving summaries" do
    user = User.create!(timezone: "UTC")
    base = Time.utc(2026, 7, 10, 12)
    [
      [ "alpha", 0 ],
      [ "beta", 60 ],
      [ "alpha", 120 ],
      [ "beta", 180 ]
    ].each do |project, offset|
      create_heartbeat(
        user: user,
        project: project,
        category: "coding",
        time: (base + offset.seconds).to_f,
        source_type: :test_entry
      )
    end
    sign_in_as(user)
    get my_projects_path
    version = inertia_page["version"]
    raw_duration_queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      sql = payload[:sql].to_s
      raw_duration_queries << sql if sql.match?(/\bFROM\s+heartbeats\b/i) && sql.include?("lagInFrame")
    end

    get my_projects_path, headers: {
      "X-Inertia" => "true",
      "X-Requested-With" => "XMLHttpRequest",
      "X-Inertia-Version" => version,
      "X-Inertia-Partial-Component" => "Projects/Index",
      "X-Inertia-Partial-Data" => "projects_data"
    }

    assert_response :success
    projects = JSON.parse(response.body).dig("props", "projects_data", "projects")
    assert_equal({ "alpha" => 120, "beta" => 120 }, projects.to_h { |project| [ project["name"], project["duration_seconds"] ] })
    assert_empty raw_duration_queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "index supports archived view state" do
    user = User.create!(timezone: "UTC")
    mapping = user.project_repo_mappings.create!(project_name: "beta")
    mapping.archive!
    create_project_heartbeats(user, "beta")

    sign_in_as(user)
    get my_projects_path(show_archived: true)

    assert_response :success
    assert_inertia_component "Projects/Index"

    page = inertia_page
    assert_equal true, page.dig("props", "show_archived")
    assert_equal 1, page.dig("props", "total_projects")
  end

  private

  def create_project_heartbeats(user, project_name)
    now = Time.current.to_i
    create_heartbeat(user: user, project: project_name, category: "coding", time: now - 1800, source_type: :test_entry)
    create_heartbeat(user: user, project: project_name, category: "coding", time: now, source_type: :test_entry)
  end
end
