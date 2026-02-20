require "test_helper"

class My::ProjectRepoMappingsControllerTest < ActionDispatch::IntegrationTest
  test "index redirects guests" do
    get my_projects_path

    assert_response :redirect
    assert_redirected_to root_path
  end

  test "index renders projects page with deferred props" do
    user = User.create!(timezone: "UTC")
    user.project_repo_mappings.create!(project_name: "alpha")
    create_project_heartbeats(user, "alpha")

    sign_in_as(user)
    get my_projects_path

    assert_response :success
    assert_includes response.body, "\"component\":\"Projects/Index\""
    assert_includes response.body, "\"deferredProps\":{\"default\":[\"projects_data\"]}"
    assert_includes response.body, "\"show_archived\":false"
    assert_includes response.body, "\"total_projects\":1"
  end

  test "index supports archived view state" do
    user = User.create!(timezone: "UTC")
    mapping = user.project_repo_mappings.create!(project_name: "beta")
    mapping.archive!
    create_project_heartbeats(user, "beta")

    sign_in_as(user)
    get my_projects_path(show_archived: true)

    assert_response :success
    assert_includes response.body, "\"component\":\"Projects/Index\""
    assert_includes response.body, "\"show_archived\":true"
    assert_includes response.body, "\"total_projects\":1"
  end

  test "repository payload uses newer tracked commit when repository metadata is stale" do
    travel_to Time.zone.parse("2026-02-19 12:00:00 UTC") do
      repository = Repository.create!(
        url: "https://github.com/hackclub/hackatime",
        host: "github.com",
        owner: "hackclub",
        name: "hackatime",
        last_commit_at: 8.months.ago
      )

      controller = My::ProjectRepoMappingsController.new
      payload = controller.send(
        :repository_payload,
        repository,
        { repository.id => 1.week.ago }
      )

      assert_equal "7 days ago", payload[:last_commit_ago]
    end
  end

  test "repository payload keeps repository metadata when it is newer than tracked commits" do
    travel_to Time.zone.parse("2026-02-19 12:00:00 UTC") do
      repository = Repository.create!(
        url: "https://github.com/hackclub/hcb",
        host: "github.com",
        owner: "hackclub",
        name: "hcb",
        last_commit_at: 2.days.ago
      )

      controller = My::ProjectRepoMappingsController.new
      payload = controller.send(
        :repository_payload,
        repository,
        { repository.id => 2.weeks.ago }
      )

      assert_equal "2 days ago", payload[:last_commit_ago]
    end
  end

  private

  def create_project_heartbeats(user, project_name)
    now = Time.current.to_i
    Heartbeat.create!(user: user, project: project_name, category: "coding", time: now - 1800, source_type: :test_entry)
    Heartbeat.create!(user: user, project: project_name, category: "coding", time: now, source_type: :test_entry)
  end

  def sign_in_as(user)
    token = user.sign_in_tokens.create!(auth_type: :email)
    get auth_token_path(token: token.token)
    assert_equal user.id, session[:user_id]
  end
end
