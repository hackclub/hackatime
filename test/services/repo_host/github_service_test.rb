require "test_helper"
require "webmock/minitest"

class RepoHost::GithubServiceTest < ActiveSupport::TestCase
  REPO_API = "https://api.github.com/repos/example/widget".freeze

  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "a primary rate limit pauses the token until GitHub's reset time" do
    reset_at = 20.minutes.from_now.to_i
    stub_request(:get, REPO_API).to_return(
      status: 403,
      headers: { "X-RateLimit-Remaining" => "0", "X-RateLimit-Reset" => reset_at.to_s },
      body: '{"message":"API rate limit exceeded"}'
    )

    error = assert_raises(RepoHost::RateLimitError) { RepoHost::GithubService.get(REPO_API, token: "token-a") }
    assert_equal reset_at, error.retry_at.to_i

    assert_raises(RepoHost::RateLimitError) { RepoHost::GithubService.get(REPO_API, token: "token-a") }
    assert_requested :get, REPO_API, times: 1

    other_token = stub_request(:get, "https://api.github.com/user").to_return(status: 200, body: "{}")
    RepoHost::GithubService.get("https://api.github.com/user", token: "token-b")
    assert_requested other_token
  end

  test "secondary rate limits pause the token using Retry-After or a fallback" do
    stub_request(:get, REPO_API).to_return(
      status: 429, headers: { "Retry-After" => "120", "X-RateLimit-Remaining" => "4000" }, body: "{}"
    )
    error = assert_raises(RepoHost::RateLimitError) { RepoHost::GithubService.get(REPO_API, token: "token-a") }
    assert_in_delta 120.seconds.from_now.to_i, error.retry_at.to_i, 2

    stub_request(:get, "#{REPO_API}/languages").to_return(
      status: 403, headers: { "X-RateLimit-Remaining" => "4000" },
      body: '{"message":"You have exceeded a secondary rate limit."}'
    )
    error = assert_raises(RepoHost::RateLimitError) { RepoHost::GithubService.get("#{REPO_API}/languages", token: "token-c") }
    assert_in_delta 60.seconds.from_now.to_i, error.retry_at.to_i, 2
  end

  test "a permission 403 is returned to the caller without pausing the token" do
    stub_request(:get, REPO_API).to_return(
      status: 403, headers: { "X-RateLimit-Remaining" => "4000" }, body: '{"message":"Resource not accessible"}'
    )

    2.times { assert_equal 403, RepoHost::GithubService.get(REPO_API, token: "token-a").status.code }
    assert_requested :get, REPO_API, times: 2
  end

  test "each request publishes its status and remaining allowance without the token" do
    stub_request(:get, "#{REPO_API}/commits/abc1234def").to_return(
      status: 200,
      headers: { "X-RateLimit-Remaining" => "4321", "X-RateLimit-Limit" => "5000", "X-RateLimit-Resource" => "core" },
      body: "{}"
    )
    events = []
    callback = ->(*, payload) { events << payload }

    ActiveSupport::Notifications.subscribed(callback, "request.github_api") do
      RepoHost::GithubService.get("#{REPO_API}/commits/abc1234def", token: "secret-token")
    end

    assert_equal 1, events.size
    event = events.first
    assert_equal "/repos/:owner/:repo/commits/:sha", event[:endpoint]
    assert_equal 200, event[:status]
    assert_equal 4321, event[:rate_limit_remaining]
    assert_equal 5000, event[:rate_limit_limit]
    assert_nil event[:rate_limit]
    assert_not_includes event.values.map(&:to_s), "secret-token"
  end

  test "renamed repositories are followed when checking existence" do
    stub_request(:get, REPO_API).to_return(status: 301, headers: { "Location" => "https://api.github.com/repositories/42" })
    stub_request(:get, "https://api.github.com/repositories/42").to_return(status: 200, body: "{}")
    user = build(:user, github_access_token: "token-a")

    assert_equal true, RepoHost::GithubService.new(user, "https://github.com/example/widget").repository_exists?
  end

  test "metadata is not synced for private repositories" do
    stub_request(:get, REPO_API).to_return(
      status: 200, headers: { "Content-Type" => "application/json" },
      body: { private: true, description: "Secret plans", stargazers_count: 1 }.to_json
    )
    user = build(:user, github_access_token: "token-a")

    assert_nil RepoHost::GithubService.new(user, "https://github.com/example/widget").fetch_repo_metadata
    assert_requested :get, %r{api\.github\.com}, times: 1
  end

  test "metadata for an empty repository has no commits instead of failing" do
    stub_request(:get, REPO_API).to_return(
      status: 200, headers: { "Content-Type" => "application/json" },
      body: { stargazers_count: 3, default_branch: "main", description: "Empty" }.to_json
    )
    stub_request(:get, "#{REPO_API}/languages").to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: "{}")
    stub_request(:get, %r{\A#{REPO_API}/commits}).to_return(status: 409, body: '{"message":"Git Repository is empty."}')
    user = build(:user, github_access_token: "token-a")

    reported = []
    original_capture = Sentry.method(:capture_message)
    Sentry.define_singleton_method(:capture_message) { |message, **| reported << message }
    begin
      metadata = RepoHost::GithubService.new(user, "https://github.com/example/widget").fetch_repo_metadata
    ensure
      Sentry.define_singleton_method(:capture_message, original_capture)
    end

    assert_empty reported
    assert_equal 3, metadata[:stars]
    assert_equal 0, metadata[:commit_count]
    assert_nil metadata[:last_commit_at]
  end
end
