require "test_helper"
require "webmock/minitest"

class AttemptProjectRepoMappingJobTest < ActiveJob::TestCase
  JSON_HEADERS = { "Content-Type" => "application/json" }.freeze

  setup do
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Flipper.enable(GithubApiJob::FLAG)
    @user = create(:user, github_uid: "1001", github_username: "octo", github_access_token: "token-a")
  end

  teardown do
    Flipper.disable(GithubApiJob::FLAG)
    ActiveJob::Base.queue_adapter = @original_queue_adapter
    Rails.cache = @original_cache
  end

  test "a public repository in the user's namespace is mapped and syncs after commit" do
    stub_request(:get, "https://api.github.com/repos/octo/widget")
      .to_return(status: 200, headers: JSON_HEADERS, body: { html_url: "https://github.com/octo/widget", private: false }.to_json)

    assert_enqueued_jobs 2, only: [ PullRepoCommitsJob, SyncRepoMetadataJob ] do
      AttemptProjectRepoMappingJob.perform_now(@user.id, "widget")
    end

    assert_equal "https://github.com/octo/widget", @user.project_repo_mappings.find_by!(project_name: "widget").repo_url
  end

  test "private repositories are never mapped automatically" do
    stub_request(:get, "https://api.github.com/repos/octo/secret")
      .to_return(status: 200, headers: JSON_HEADERS, body: { html_url: "https://github.com/octo/secret", private: true }.to_json)
    stub_request(:get, "https://api.github.com/users/octo/orgs").to_return(status: 200, headers: JSON_HEADERS, body: "[]")

    AttemptProjectRepoMappingJob.perform_now(@user.id, "secret")

    assert_not @user.project_repo_mappings.exists?(project_name: "secret")
  end

  test "an organisation repository is only mapped where the user has commits" do
    stub_request(:get, "https://api.github.com/repos/octo/website").to_return(status: 404, body: "{}")
    stub_request(:get, "https://api.github.com/users/octo/orgs")
      .to_return(status: 200, headers: JSON_HEADERS, body: [ { login: "alpha" }, { login: "beta" } ].to_json)
    stub_public_repo("alpha", "website")
    stub_public_repo("beta", "website")
    stub_commits("alpha", "website", [])
    stub_commits("beta", "website", [ { sha: "abc" } ])

    AttemptProjectRepoMappingJob.perform_now(@user.id, "website")

    assert_equal "https://github.com/beta/website", @user.project_repo_mappings.find_by!(project_name: "website").repo_url
  end

  test "an organisation match that is ambiguous is left for the user to map" do
    stub_request(:get, "https://api.github.com/repos/octo/website").to_return(status: 404, body: "{}")
    stub_request(:get, "https://api.github.com/users/octo/orgs")
      .to_return(status: 200, headers: JSON_HEADERS, body: [ { login: "alpha" }, { login: "beta" }, { login: "gamma" } ].to_json)
    %w[alpha beta].each do |org|
      stub_public_repo(org, "website")
      stub_commits(org, "website", [ { sha: "#{org}-sha" } ])
    end

    AttemptProjectRepoMappingJob.perform_now(@user.id, "website")

    assert_not @user.project_repo_mappings.exists?(project_name: "website")
    assert Rails.cache.exist?(AttemptProjectRepoMappingJob.attempt_cache_key(@user.id, "website"))
    assert_not_requested :get, %r{api\.github\.com/repos/gamma/}
  end

  test "while GitHub sync is switched off nothing is queued or requested" do
    Flipper.disable(GithubApiJob::FLAG)

    assert_no_enqueued_jobs only: AttemptProjectRepoMappingJob do
      AttemptProjectRepoMappingJob.enqueue_for(@user, "widget")
    end
    AttemptProjectRepoMappingJob.perform_now(@user.id, "widget")
    PullRepoCommitsJob.perform_now(@user.id, "octo", "widget")

    assert_not_requested :any, /api\.github\.com/
  end

  test "a miss is remembered so heartbeats stop queueing lookups" do
    stub_request(:get, "https://api.github.com/repos/octo/notes").to_return(status: 404, body: "{}")
    stub_request(:get, "https://api.github.com/users/octo/orgs")
      .to_return(status: 200, headers: JSON_HEADERS, body: [ { login: "club" } ].to_json)
    stub_request(:get, "https://api.github.com/repos/club/notes").to_return(status: 404, body: "{}")
    stub_request(:get, "https://api.github.com/repos/octo/drafts").to_return(status: 404, body: "{}")
    stub_request(:get, "https://api.github.com/repos/club/drafts").to_return(status: 404, body: "{}")

    AttemptProjectRepoMappingJob.perform_now(@user.id, "notes")
    AttemptProjectRepoMappingJob.perform_now(@user.id, "drafts")

    assert_no_enqueued_jobs only: AttemptProjectRepoMappingJob do
      AttemptProjectRepoMappingJob.enqueue_for(@user, "notes")
    end
    assert_enqueued_with(job: AttemptProjectRepoMappingJob, args: [ @user.id, "fresh-project" ]) do
      AttemptProjectRepoMappingJob.enqueue_for(@user, "fresh-project")
    end
    assert_requested :get, "https://api.github.com/users/octo/orgs", times: 1
  end

  test "project names that cannot be GitHub repositories are not queued" do
    assert_no_enqueued_jobs only: AttemptProjectRepoMappingJob do
      [ "My Project (old)", "..", "<<LAST_PROJECT>>", "" ].each do |name|
        AttemptProjectRepoMappingJob.enqueue_for(@user, name)
      end
    end
  end

  test "lookups stop once the user's daily request budget is spent and are retried later" do
    budget_key = "github_repo_mapping_requests:#{@user.id}:#{Date.current.iso8601}"
    Rails.cache.write(budget_key, AttemptProjectRepoMappingJob::DAILY_REQUEST_BUDGET, raw: true)

    AttemptProjectRepoMappingJob.perform_now(@user.id, "widget")

    assert_not_requested :any, /api\.github\.com/
    assert_not Rails.cache.exist?(AttemptProjectRepoMappingJob.attempt_cache_key(@user.id, "widget"))
  end

  test "a rate limited lookup is deferred without being remembered as a miss" do
    stub_request(:get, "https://api.github.com/repos/octo/widget").to_return(
      status: 403,
      headers: { "X-RateLimit-Remaining" => "0", "X-RateLimit-Reset" => 10.minutes.from_now.to_i.to_s },
      body: "{}"
    )

    AttemptProjectRepoMappingJob.perform_now(@user.id, "widget")

    assert_not Rails.cache.exist?(AttemptProjectRepoMappingJob.attempt_cache_key(@user.id, "widget"))
    assert_not @user.project_repo_mappings.exists?(project_name: "widget")
  end

  test "a rejected token is cleared and the lookup is not remembered as a miss" do
    stub_request(:get, "https://api.github.com/repos/octo/widget").to_return(status: 401, body: '{"message":"Bad credentials"}')

    AttemptProjectRepoMappingJob.perform_now(@user.id, "widget")

    @user.reload
    assert_nil @user.github_access_token
    assert_equal "1001", @user.github_uid
    assert_not Rails.cache.exist?(AttemptProjectRepoMappingJob.attempt_cache_key(@user.id, "widget"))
    assert_not_requested :get, "https://api.github.com/users/octo/orgs"
  end

  test "users without a linked GitHub account are not queued" do
    user = create(:user)

    assert_no_enqueued_jobs only: AttemptProjectRepoMappingJob do
      AttemptProjectRepoMappingJob.enqueue_for(user, "widget")
    end
  end

  private

  def stub_public_repo(owner, name)
    stub_request(:get, "https://api.github.com/repos/#{owner}/#{name}")
      .to_return(status: 200, headers: JSON_HEADERS, body: { html_url: "https://github.com/#{owner}/#{name}", private: false }.to_json)
  end

  def stub_commits(owner, name, commits)
    stub_request(:get, "https://api.github.com/repos/#{owner}/#{name}/commits?author=octo&per_page=1")
      .to_return(status: 200, headers: JSON_HEADERS, body: commits.to_json)
  end
end
