require "test_helper"

class My::ProjectRepoMappingsControllerTest < ActionDispatch::IntegrationTest
  test "index redirects guests" do
    get my_projects_path

    assert_response :redirect
    assert_redirected_to root_path
  end

  test "index renders project rollups synchronously when available" do
    user = User.create!(timezone: "UTC")
    user.project_repo_mappings.create!(project_name: "alpha")
    create_project_heartbeats(user, "alpha")
    DashboardRollupRefreshService.new(user: user).call

    sign_in_as(user)
    get my_projects_path

    assert_response :success
    assert_inertia_component "Projects/Index"

    page = inertia_page
    assert_equal false, page.dig("props", "show_archived")
    assert_nil page["deferredProps"]
    assert_equal [ "alpha" ], page.dig("props", "projects_data", "projects").map { |project| project["name"] }
  end

  test "index renders project data inline when rollups are missing" do
    user = User.create!(timezone: "UTC")
    user.project_repo_mappings.create!(project_name: "alpha")
    create_project_heartbeats(user, "alpha")

    sign_in_as(user)
    get my_projects_path

    assert_response :success

    page = inertia_page
    assert_nil page["deferredProps"]
    assert_equal [ "alpha" ], page.dig("props", "projects_data", "projects").map { |project| project["name"] }
  end

  test "index renders rollup-backed project data inline on inertia navigation" do
    user = User.create!(timezone: "UTC")
    user.project_repo_mappings.create!(project_name: "alpha")
    create_project_heartbeats(user, "alpha")
    DashboardRollupRefreshService.new(user: user).call

    sign_in_as(user)
    get my_projects_path
    version = inertia_page["version"]

    get my_projects_path, headers: {
      "X-Inertia" => "true",
      "X-Requested-With" => "XMLHttpRequest",
      "X-Inertia-Version" => version,
      "X-Inertia-Except-Once-Props" => "layout.footer"
    }

    assert_response :success

    page = JSON.parse(response.body)
    assert_nil page["deferredProps"]
    assert_equal [ "alpha" ], page.dig("props", "projects_data", "projects").map { |project| project["name"] }
    assert_nil page.dig("props", "layout", "footer")
  end

  test "index renders interval-filtered project data inline" do
    user = User.create!(timezone: "UTC")
    user.project_repo_mappings.create!(project_name: "alpha")
    create_project_heartbeats(user, "alpha")

    sign_in_as(user)
    get my_projects_path(interval: "last_7_days")

    assert_response :success

    page = inertia_page
    assert_nil page["deferredProps"]
    assert_equal [ "alpha" ], page.dig("props", "projects_data", "projects").map { |project| project["name"] }
  end

  test "index supports archived view state" do
    user = User.create!(timezone: "UTC")
    mapping = user.project_repo_mappings.create!(project_name: "beta")
    mapping.archive!
    create_project_heartbeats(user, "beta")
    DashboardRollupRefreshService.new(user: user).call

    sign_in_as(user)
    get my_projects_path(show_archived: true)

    assert_response :success
    assert_inertia_component "Projects/Index"

    page = inertia_page
    assert_equal true, page.dig("props", "show_archived")
    assert_equal [ "beta" ], page.dig("props", "projects_data", "projects").map { |project| project["name"] }
  end

  private

  def create_project_heartbeats(user, project_name)
    now = Time.current.to_i
    Heartbeat.create!(user: user, project: project_name, category: "coding", time: now - 1800, source_type: :test_entry)
    Heartbeat.create!(user: user, project: project_name, category: "coding", time: now, source_type: :test_entry)
  end
end
