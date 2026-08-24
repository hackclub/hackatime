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
end
