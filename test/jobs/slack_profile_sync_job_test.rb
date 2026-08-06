require "test_helper"
require "webmock/minitest"

class SlackProfileSyncJobTest < ActiveJob::TestCase
  setup do
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    @original_token = ENV["SLACK_USER_OAUTH_TOKEN"]
    ENV["SLACK_USER_OAUTH_TOKEN"] = "workspace-token"
  end

  teardown do
    ActiveJob::Base.queue_adapter = @original_queue_adapter
    ENV["SLACK_USER_OAUTH_TOKEN"] = @original_token
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "updates and persists the Slack profile" do
    user = User.create!(timezone: "UTC", slack_uid: "U_PROFILE_SYNC")
    stub_request(:get, "https://slack.com/api/users.info?user=U_PROFILE_SYNC")
      .with(headers: { "Authorization" => "Bearer workspace-token" })
      .to_return(body: {
        ok: true,
        user: {
          name: "fallback-name",
          profile: {
            display_name_normalized: "slack-name",
            image_192: "https://example.com/avatar.png"
          }
        }
      }.to_json)

    SlackProfileSyncJob.perform_now(user.id)

    user.reload
    assert_equal "slack-name", user.slack_username
    assert_equal "https://example.com/avatar.png", user.slack_avatar_url
    assert_not_nil user.slack_synced_at
  end

  test "retries Slack rate limits without changing the existing profile" do
    user = User.create!(
      timezone: "UTC",
      slack_uid: "U_RATE_LIMITED",
      slack_username: "existing-name",
      slack_avatar_url: "https://example.com/existing-avatar.png"
    )
    stub_request(:get, "https://slack.com/api/users.info?user=U_RATE_LIMITED")
      .to_return(
        status: 429,
        headers: { "Retry-After" => "60" },
        body: { ok: false, error: "ratelimited" }.to_json
      )

    travel_to Time.current.change(usec: 0) do
      assert_enqueued_with(job: SlackProfileSyncJob, args: [ user.id ], at: 60.seconds.from_now) do
        SlackProfileSyncJob.perform_now(user.id)
      end
    end

    user.reload
    assert_equal "existing-name", user.slack_username
    assert_equal "https://example.com/existing-avatar.png", user.slack_avatar_url
    assert_nil user.slack_synced_at
  end

  test "fails visibly and preserves the existing profile when Slack returns an API error" do
    synced_at = 2.days.ago
    user = User.create!(
      timezone: "UTC",
      slack_uid: "U_API_ERROR",
      slack_username: "existing-name",
      slack_avatar_url: "https://example.com/existing-avatar.png",
      slack_synced_at: synced_at
    )
    stub_request(:get, "https://slack.com/api/users.info?user=U_API_ERROR")
      .to_return(body: { ok: false, error: "missing_scope" }.to_json)

    error = assert_raises(SlackIntegration::ApiError) do
      SlackProfileSyncJob.perform_now(user.id)
    end

    assert_includes error.message, "missing_scope"
    user.reload
    assert_equal "existing-name", user.slack_username
    assert_equal "https://example.com/existing-avatar.png", user.slack_avatar_url
    assert_in_delta synced_at, user.slack_synced_at, 1.second
  end

  test "does nothing when the user has no Slack ID" do
    user = User.create!(timezone: "UTC")

    SlackProfileSyncJob.perform_now(user.id)

    assert_not_requested :get, /slack\.com/
  end

  test "does not restore Slack profile data when anonymization finishes during the request" do
    user = User.create!(timezone: "UTC", slack_uid: "U_DELETION_RACE")
    stub_request(:get, "https://slack.com/api/users.info?user=U_DELETION_RACE")
      .to_return do
        AnonymizeUserService.call(user)
        {
          body: {
            ok: true,
            user: {
              name: "deleted-name",
              profile: { image_192: "https://example.com/deleted-avatar.png" }
            }
          }.to_json
        }
      end

    SlackProfileSyncJob.perform_now(user.id)

    user.reload
    assert user.anonymized?
    assert_nil user.slack_uid
    assert_nil user.slack_username
    assert_nil user.slack_avatar_url
  end
end
