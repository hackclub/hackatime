require "test_helper"
require "webmock/minitest"

class PullRepoCommitsJobTest < ActiveJob::TestCase
  COMMITS_URL = %r{\Ahttps://api\.github\.com/repos/example/widget/commits\?}

  setup do
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    @user = create(:user, github_uid: "1001", github_username: "octo", github_access_token: "token-a")
    @repository = create(:repository, owner: "example", name: "widget")
  end

  teardown do
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  test "stores only the user's commits from a single list request" do
    stub_request(:get, COMMITS_URL)
      .with(query: hash_including("author" => "octo", "per_page" => "100"))
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: [
        commit_json("aaa111", author_id: 1001, login: "octo", committed_at: "2026-10-12T09:30:00Z"),
        commit_json("bbb222", author_id: 2002, login: "someone-else", committed_at: "2026-10-12T10:00:00Z")
      ].to_json)

    PullRepoCommitsJob.perform_now(@user.id, "example", "widget")
    PullRepoCommitsJob.perform_now(@user.id, "example", "widget")

    commits = Commit.where(user: @user)
    assert_equal [ "aaa111" ], commits.pluck(:sha)
    commit = commits.first
    assert_equal @repository.id, commit.repository_id
    assert_equal Time.utc(2026, 10, 12, 9, 30), commit.created_at
    assert_equal "https://github.com/example/widget/commit/aaa111", commit.github_raw["html_url"]
    assert_requested :get, COMMITS_URL, times: 2
  end

  test "an empty repository stores nothing and does not fail" do
    stub_request(:get, COMMITS_URL).to_return(status: 409, body: '{"message":"Git Repository is empty."}')

    PullRepoCommitsJob.perform_now(@user.id, "example", "widget")

    assert_equal 0, Commit.count
  end

  test "timeouts are retried later instead of failing the job" do
    stub_request(:get, COMMITS_URL).to_timeout

    assert_enqueued_with(job: PullRepoCommitsJob, args: [ @user.id, "example", "widget" ]) do
      PullRepoCommitsJob.perform_now(@user.id, "example", "widget")
    end
  end

  test "a revoked token is cleared without removing the user from the leaderboard" do
    stub_request(:get, COMMITS_URL).to_return(status: 401, body: '{"message":"Bad credentials"}')
    2.times do |index|
      create(:heartbeat, user: @user, entity: "src/app.rb", type: "file", category: "coding",
        editor: "vscode", project: "widget", source_type: :test_entry,
        time: (1.hour.ago + (index * 2).minutes).to_f)
    end

    PullRepoCommitsJob.perform_now(@user.id, "example", "widget")
    LeaderboardUpdateJob.perform_now(:daily, Date.current, force_update: true)

    @user.reload
    assert_nil @user.github_access_token
    assert_equal "1001", @user.github_uid
    board = Leaderboard.find_by!(start_date: Date.current, period_type: :daily, timezone_utc_offset: nil)
    assert_includes board.entries.pluck(:user_id), @user.id
  end

  private

  def commit_json(sha, author_id:, login:, committed_at:)
    {
      sha: sha,
      html_url: "https://github.com/example/widget/commit/#{sha}",
      author: { id: author_id, login: login },
      commit: { committer: { date: committed_at }, author: { date: committed_at } }
    }
  end
end
