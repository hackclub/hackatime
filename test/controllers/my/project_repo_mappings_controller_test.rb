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
    assert_equal 1, page.dig("props", "total_projects")
    assert_nil page["deferredProps"]
    assert_equal [ "alpha" ], page.dig("props", "projects_data", "projects").map { |project| project["name"] }
  end

  test "index falls back to deferred project data when default rollups are missing" do
    user = User.create!(timezone: "UTC")
    user.project_repo_mappings.create!(project_name: "alpha")
    create_project_heartbeats(user, "alpha")

    sign_in_as(user)
    get my_projects_path

    assert_response :success

    page = inertia_page
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

  test "index supports archived view state" do
    user = User.create!(timezone: "UTC")
    user.project_repo_mappings.create!(project_name: "alpha")
    create_project_heartbeats(user, "alpha")
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
    assert_equal 1, page.dig("props", "total_projects")
    assert_equal [ "projects_data" ], page.dig("deferredProps", "default")
  end

  test "show preserves percent-encoded text in project names" do
    user = User.create!(timezone: "UTC")
    project_name = "folder/café ?# 100%25"
    create_project_heartbeats(user, project_name)

    sign_in_as(user)
    get my_project_path(project_name: project_name)

    assert_response :success
    assert_equal project_name, inertia_page.dig("props", "project_name")
  end

  test "archive accepts a slash as the project name" do
    user = User.create!(timezone: "UTC")
    mapping = user.project_repo_mappings.create!(project_name: "/")

    sign_in_as(user)
    patch archive_my_project_repo_mapping_path(project_name: "/")

    assert_redirected_to my_projects_path
    assert_predicate mapping.reload, :archived?
  end

  test "update returns validation errors to the projects page" do
    user = User.create!(timezone: "UTC", github_uid: "123")
    mapping = user.project_repo_mappings.create!(project_name: "alpha")

    sign_in_as(user)
    patch my_project_repo_mapping_path(project_name: mapping.project_name),
          params: { project_repo_mapping: { repo_url: "https://example.com/owner/repo" } },
          headers: { "HTTP_REFERER" => my_projects_url(show_archived: true) }

    assert_redirected_to my_projects_path(show_archived: true)
    assert_includes session[:inertia_errors][:repo_url], "We only support GitHub repositories"
    assert_equal mapping.project_name, session[:inertia_errors][:repo_url_project_name]
    assert_equal "https://example.com/owner/repo", session[:inertia_errors][:repo_url_value]
  end

  private

  def create_project_heartbeats(user, project_name)
    now = Time.current.to_i
    Heartbeat.create!(user: user, project: project_name, category: "coding", time: now - 1800, source_type: :test_entry)
    Heartbeat.create!(user: user, project: project_name, category: "coding", time: now, source_type: :test_entry)
  end
end
