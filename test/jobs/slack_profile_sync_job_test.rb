require "test_helper"
require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)

class SlackProfileSyncJobTest < ActiveJob::TestCase
  setup do
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
  end

  teardown do
    ActiveJob::Base.queue_adapter = @original_queue_adapter
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "updates and persists the Slack profile from Cachet" do
    user = create(:user, slack_uid: "U_PROFILE_SYNC")
    stub_request(:get, "https://cachet.hackclub.com/users/U_PROFILE_SYNC")
      .with { |request| !request.headers.key?("Authorization") }
      .to_return(body: {
        displayName: "slack-name",
        realName: "Real Name",
        imageUrl: "https://example.com/avatar.png"
      }.to_json)

    SlackProfileSyncJob.perform_now(user.id)

    user.reload
    assert_equal "slack-name", user.slack_username
    assert_equal "https://example.com/avatar.png", user.slack_avatar_url
    assert_not_nil user.slack_synced_at
  end

  test "syncs a profile with a legacy Rails timezone name" do
    user = create(:user, slack_uid: "U_LEGACY_TIMEZONE")
    user.update_column(:timezone, "Eastern Time (US & Canada)")
    stub_request(:get, "https://cachet.hackclub.com/users/U_LEGACY_TIMEZONE")
      .to_return(body: { displayName: "updated-name", imageUrl: "https://example.com/avatar.png" }.to_json)

    SlackProfileSyncJob.perform_now(user.id)

    user.reload
    assert_equal "America/New_York", user.timezone
    assert_equal "updated-name", user.slack_username
    assert_equal "https://example.com/avatar.png", user.slack_avatar_url
    assert_not_nil user.slack_synced_at
  end

  test "preserves the existing profile while Cachet is fetching and saves it on retry" do
    synced_at = 2.days.ago
    user = create(:user,
      slack_uid: "U_PENDING",
      slack_username: "existing-name",
      slack_avatar_url: "https://example.com/existing-avatar.png",
      slack_synced_at: synced_at
    )
    stub_request(:get, "https://cachet.hackclub.com/users/U_PENDING")
      .to_return(
        { status: 202, body: { displayName: "Unknown", realName: "", imageUrl: "https://example.com/placeholder.png" }.to_json },
        { status: 200, body: { displayName: "updated-name", imageUrl: "https://example.com/updated-avatar.png" }.to_json }
      )

    travel_to Time.current.change(usec: 0) do
      assert_enqueued_with(job: SlackProfileSyncJob, args: [ user.id ], at: 60.seconds.from_now) do
        SlackProfileSyncJob.perform_now(user.id)
      end
    end

    user.reload
    assert_equal "existing-name", user.slack_username
    assert_equal "https://example.com/existing-avatar.png", user.slack_avatar_url
    assert_in_delta synced_at, user.slack_synced_at, 1.second

    perform_enqueued_jobs

    user.reload
    assert_equal "updated-name", user.slack_username
    assert_equal "https://example.com/updated-avatar.png", user.slack_avatar_url
    assert_operator user.slack_synced_at, :>, synced_at
  end

  test "stops retrying a Cachet cache miss after five attempts without marking it synced" do
    user = create(:user, slack_uid: "U_UNCACHED")
    stub_request(:get, "https://cachet.hackclub.com/users/U_UNCACHED")
      .to_return(status: 202, body: { displayName: "Unknown" }.to_json)

    job = SlackProfileSyncJob.new(user.id)
    job.executions = 4

    assert_no_enqueued_jobs do
      job.perform_now
    end

    assert_nil user.reload.slack_synced_at
    assert_nil user.slack_username
    assert_nil user.slack_avatar_url
  end

  test "fails visibly and preserves the existing profile when Cachet returns an API error" do
    synced_at = 2.days.ago
    user = create(:user,
      slack_uid: "U_API_ERROR",
      slack_username: "existing-name",
      slack_avatar_url: "https://example.com/existing-avatar.png",
      slack_synced_at: synced_at
    )
    stub_request(:get, "https://cachet.hackclub.com/users/U_API_ERROR")
      .to_return(status: 500, body: { error: { message: "Unexpected error" } }.to_json)

    error = assert_raises(Cachet::ApiError) do
      SlackProfileSyncJob.perform_now(user.id)
    end

    assert_includes error.message, "HTTP 500"
    user.reload
    assert_equal "existing-name", user.slack_username
    assert_equal "https://example.com/existing-avatar.png", user.slack_avatar_url
    assert_in_delta synced_at, user.slack_synced_at, 1.second
  end

  test "does nothing when the user has no Slack ID" do
    user = create(:user)

    SlackProfileSyncJob.perform_now(user.id)

    assert_not_requested :get, /cachet\.hackclub\.com/
  end
end
