require "test_helper"

class ProjectRepoMappingTest < ActiveSupport::TestCase
  test "archive and unarchive toggle archived state" do
    user = create(:user)
    mapping = create(:project_repo_mapping, user: user, project_name: "hackatime")

    assert_not mapping.archived?

    mapping.archive!
    assert mapping.reload.archived?

    mapping.unarchive!
    assert_not mapping.reload.archived?
  end

  test "project name must be unique per user" do
    user = create(:user)
    create(:project_repo_mapping, user: user, project_name: "same-project")

    duplicate = user.project_repo_mappings.build(project_name: "same-project")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:project_name], "has already been taken"
  end

  test "existing GitHub repository URLs are valid" do
    user = create(:user, github_access_token: "github-token")
    stub_request(:get, "https://api.github.com/repos/yousseftechdev/RoboEyesMacroPad")
      .to_return(status: 200, body: "{}")
    mapping = user.project_repo_mappings.build(
      project_name: "macro-pad",
      repo_url: "https://github.com/yousseftechdev/RoboEyesMacroPad"
    )

    assert_predicate mapping, :valid?
  end

  test "nonexistent GitHub repository URLs are invalid" do
    user = create(:user, github_access_token: "github-token")
    stub_request(:get, "https://api.github.com/repos/hackcl/hackatime")
      .to_return(status: 404, body: '{"message":"Not Found"}')
    mapping = user.project_repo_mappings.build(
      project_name: "missing",
      repo_url: "https://github.com/hackcl/hackatime"
    )

    assert_not mapping.valid?
    assert_includes mapping.errors[:repo_url], "does not exist or is not accessible"
  end

  test "temporary GitHub failures do not mark repository URLs as nonexistent" do
    user = create(:user, github_access_token: "github-token")
    stub_request(:get, "https://api.github.com/repos/example/repository")
      .to_return(status: 503, body: '{"message":"Service unavailable"}')
    mapping = user.project_repo_mappings.build(
      project_name: "repository",
      repo_url: "https://github.com/example/repository"
    )

    assert_predicate mapping, :valid?
  end

  test "TLS failures do not mark repository URLs as nonexistent" do
    user = create(:user, github_access_token: "github-token")
    stub_request(:get, "https://api.github.com/repos/example/repository")
      .to_raise(OpenSSL::SSL::SSLError.new("certificate verify failed"))
    mapping = user.project_repo_mappings.build(
      project_name: "repository",
      repo_url: "https://github.com/example/repository"
    )

    assert_predicate mapping, :valid?
  end

  test "unchanged repository URLs are not remotely verified" do
    user = create(:user, github_access_token: "github-token")
    mapping = create(:project_repo_mapping, user: user, project_name: "repository")
    mapping.update_column(:repo_url, "https://github.com/example/repository")

    mapping.archive!

    assert_predicate mapping.reload, :archived?
    assert_not_requested :get, "https://api.github.com/repos/example/repository"
  end

  test "currently active projects are each user's latest mapped project and skip soft-deleted heartbeats" do
    Rails.cache.delete("project_repo_mappings/currently_active_by_user")
    user = create(:user)
    create(:project_repo_mapping, user: user, project_name: "live")
    create(:project_repo_mapping, user: user, project_name: "ghost")

    create_recent_heartbeat(user: user, project: "live", time: 1.minute.ago.to_f)
    # a soft-deleted recent heartbeat must NOT resurrect "ghost" as active
    create_recent_heartbeat(user: user, project: "ghost", time: 30.seconds.ago.to_f, deleted_at: Time.current)

    result = ProjectRepoMapping.currently_active_by_user

    assert_equal [ user.id ], result.keys
    assert_equal "live", result[user.id].project_name
  end

  test "currently active projects exclude old heartbeats and non-direct source types" do
    Rails.cache.delete("project_repo_mappings/currently_active_by_user")
    user = create(:user)
    create(:project_repo_mapping, user: user, project_name: "stale")
    create(:project_repo_mapping, user: user, project_name: "imported")

    create_recent_heartbeat(user: user, project: "stale", time: 10.minutes.ago.to_f)
    create_recent_heartbeat(user: user, project: "imported", time: 1.minute.ago.to_f, source_type: :wakapi_import)

    assert_empty ProjectRepoMapping.currently_active_by_user
  end

  private

  def create_recent_heartbeat(user:, project:, **attrs)
    create(:heartbeat, user:, project:, entity: "src/#{project}.rb", source_type: :direct_entry, time: Time.current.to_f, **attrs)
  end
end
