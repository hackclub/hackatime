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

    original_batch_size = ReconcileActiveRepositoriesJob::BATCH_SIZE
    ReconcileActiveRepositoriesJob.send(:remove_const, :BATCH_SIZE)
    ReconcileActiveRepositoriesJob.const_set(:BATCH_SIZE, 1)
    begin
      ReconcileActiveRepositoriesJob.perform_now
    ensure
      ReconcileActiveRepositoriesJob.send(:remove_const, :BATCH_SIZE)
      ReconcileActiveRepositoriesJob.const_set(:BATCH_SIZE, original_batch_size)
    end

    assert_equal [ [ never.id ] ], enqueued_args(SyncRepoMetadataJob)
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

  private

  def map(user, project_name, repository, coded_at:)
    create(:heartbeat, user: user, entity: "src/app.rb", type: "file", category: "coding",
      editor: "vscode", project: project_name, source_type: :test_entry, time: coded_at.to_f)
    create(:project_repo_mapping, user: user, project_name: project_name, repository: repository)
  end

  def enqueued_args(job_class)
    enqueued_jobs.select { |job| job["job_class"] == job_class.name }.map { |job| job["arguments"] }
  end
end
