require "test_helper"
require "webmock/minitest"

class ReconcileActiveRepositoriesJobTest < ActiveJob::TestCase
  setup do
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    Flipper.enable(GithubApiJob::FLAG)
    @coder = create(:user, github_uid: "1001", github_username: "coder", github_access_token: "token-a")
  end

  teardown do
    Flipper.disable(GithubApiJob::FLAG)
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  test "syncs stale repositories of projects coded on recently and pulls commits for the active coders" do
    stale = create(:repository, last_synced_at: 2.months.ago)
    map(@coder, "stale-project", stale, coded_at: 2.hours.ago)
    idle_mapper = create(:user, github_uid: "2002", github_access_token: "token-b")
    map(idle_mapper, "same-repo-old-name", stale, coded_at: 3.days.ago)

    fresh = create(:repository, last_synced_at: 1.hour.ago)
    map(@coder, "fresh-project", fresh, coded_at: 1.hour.ago)
    idle = create(:repository, last_synced_at: 2.months.ago)
    map(@coder, "idle-project", idle, coded_at: 3.days.ago)
    archived = create(:repository, last_synced_at: 2.months.ago)
    map(@coder, "archived-project", archived, coded_at: 1.hour.ago).archive!
    clear_enqueued_jobs

    ReconcileActiveRepositoriesJob.perform_now

    assert_equal [ [ stale.id ] ], enqueued_args(SyncRepoMetadataJob)
    assert_equal [ [ @coder.id, stale.owner, stale.name ] ], enqueued_args(PullRepoCommitsJob)
  end

  test "never-synced repositories go first and each run is capped" do
    older = create(:repository, last_synced_at: 3.months.ago)
    never = create(:repository, last_synced_at: nil)
    map(@coder, "older", older, coded_at: 1.hour.ago)
    map(@coder, "never", never, coded_at: 1.hour.ago)

    with_const(:BATCH_SIZE, 1) { ReconcileActiveRepositoriesJob.perform_now }

    assert_equal [ [ never.id ] ], enqueued_args(SyncRepoMetadataJob)
  end

  test "commit pulls are capped per run and each one gets its own slot" do
    shared = create(:repository, last_synced_at: 2.months.ago)
    other = create(:repository, last_synced_at: 1.month.ago)
    coders = [ @coder ] + 2.times.map { |i| create(:user, github_uid: "30#{i}", github_access_token: "token-#{i}") }
    coders.each { |coder| map(coder, "shared-#{coder.id}", shared, coded_at: 1.hour.ago) }
    map(@coder, "other", other, coded_at: 1.hour.ago)

    with_const(:COMMIT_PULL_BUDGET, 2) { ReconcileActiveRepositoriesJob.perform_now }

    pulls = enqueued_jobs.select { |job| job["job_class"] == "PullRepoCommitsJob" }.sort_by { |job| job[:at] }
    assert_equal 2, pulls.size
    assert pulls.all? { |job| job["arguments"].drop(1) == [ shared.owner, shared.name ] }
    assert_equal 2, pulls.map { |job| job["arguments"].first }.uniq.size
    assert_in_delta ReconcileActiveRepositoriesJob::SPACING.to_f, pulls.last[:at] - pulls.first[:at], 1.0
    assert_equal [ [ shared.id ], [ other.id ] ], enqueued_args(SyncRepoMetadataJob)
  end

  test "does nothing while github_sync is off" do
    map(@coder, "stale-project", create(:repository, last_synced_at: 2.months.ago), coded_at: 1.hour.ago)
    Flipper.disable(GithubApiJob::FLAG)

    ReconcileActiveRepositoriesJob.perform_now

    assert_empty enqueued_args(SyncRepoMetadataJob)
    assert_empty enqueued_args(PullRepoCommitsJob)
  end

  test "a repository GitHub no longer serves is not picked again on the next run" do
    repository = create(:repository, owner: "example", name: "gone", last_synced_at: 2.months.ago)
    map(@coder, "gone", repository, coded_at: 1.hour.ago)
    stub_request(:get, "https://api.github.com/repos/example/gone").to_return(status: 404, body: "{}")

    SyncRepoMetadataJob.perform_now(repository.id)
    ReconcileActiveRepositoriesJob.perform_now

    assert_operator repository.reload.last_synced_at, :>, 1.minute.ago
    assert_empty enqueued_args(SyncRepoMetadataJob)
  end

  test "a temporary GitHub failure keeps the repository due for the next run" do
    repository = create(:repository, owner: "example", name: "flaky", last_synced_at: 2.months.ago)
    map(@coder, "flaky", repository, coded_at: 1.hour.ago)
    stub_request(:get, "https://api.github.com/repos/example/flaky").to_return(status: 503, body: "{}")

    assert_enqueued_with(job: SyncRepoMetadataJob, args: [ repository.id ]) do
      SyncRepoMetadataJob.perform_now(repository.id)
    end
    clear_enqueued_jobs
    ReconcileActiveRepositoriesJob.perform_now

    assert_operator repository.reload.last_synced_at, :<, 1.month.ago
    assert_equal [ [ repository.id ] ], enqueued_args(SyncRepoMetadataJob)
  end

  test "a server error on the commit listing does not overwrite the stored latest commit" do
    last_commit_at = Time.utc(2026, 10, 1, 12)
    repository = create(:repository, owner: "example", name: "widget", last_synced_at: 2.months.ago,
      last_commit_at:, commit_count: 42)
    map(@coder, "widget", repository, coded_at: 1.hour.ago)
    json = { "Content-Type" => "application/json" }
    stub_request(:get, "https://api.github.com/repos/example/widget")
      .to_return(status: 200, headers: json, body: { default_branch: "main", stargazers_count: 5 }.to_json)
    stub_request(:get, "https://api.github.com/repos/example/widget/languages").to_return(status: 200, headers: json, body: "{}")
    stub_request(:get, %r{\Ahttps://api\.github\.com/repos/example/widget/commits}).to_return(status: 500, body: "{}")

    SyncRepoMetadataJob.perform_now(repository.id)

    repository.reload
    assert_equal last_commit_at, repository.last_commit_at
    assert_equal 42, repository.commit_count
    assert_operator repository.last_synced_at, :<, 1.month.ago
  end

  test "repeated server errors stop retrying without failing the job" do
    repository = create(:repository, owner: "example", name: "down", last_synced_at: 2.months.ago)
    map(@coder, "down", repository, coded_at: 1.hour.ago)
    stub_request(:get, "https://api.github.com/repos/example/down").to_return(status: 502, body: "{}")

    perform_enqueued_jobs(only: SyncRepoMetadataJob) do
      assert_nothing_raised { SyncRepoMetadataJob.perform_later(repository.id) }
    end

    assert_requested :get, "https://api.github.com/repos/example/down", times: 3
    assert_operator repository.reload.last_synced_at, :<, 1.month.ago
  end

  private

  def with_const(name, value)
    original = ReconcileActiveRepositoriesJob.const_get(name)
    ReconcileActiveRepositoriesJob.send(:remove_const, name)
    ReconcileActiveRepositoriesJob.const_set(name, value)
    yield
  ensure
    ReconcileActiveRepositoriesJob.send(:remove_const, name)
    ReconcileActiveRepositoriesJob.const_set(name, original)
  end

  def map(user, project_name, repository, coded_at:)
    create(:heartbeat, user: user, entity: "src/app.rb", type: "file", category: "coding",
      editor: "vscode", project: project_name, source_type: :test_entry, time: coded_at.to_f)
    create(:project_repo_mapping, user: user, project_name: project_name, repository: repository)
  end

  def enqueued_args(job_class)
    enqueued_jobs.select { |job| job["job_class"] == job_class.name }.map { |job| job["arguments"] }
  end
end
