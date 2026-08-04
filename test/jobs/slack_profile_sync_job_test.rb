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

  test "reconciles the Slack email while preserving the previous email for sign-in" do
    user = User.create!(timezone: "UTC", slack_uid: "U_EMAIL_SYNC")
    old_email = user.email_addresses.create!(email: "old@example.com", source: :slack)
    stub_request(:get, "https://slack.com/api/users.info?user=U_EMAIL_SYNC")
      .with(headers: { "Authorization" => "Bearer workspace-token" })
      .to_return(body: {
        ok: true,
        user: {
          name: "email-sync",
          profile: { email: "New@Example.com" }
        }
      }.to_json)

    SlackProfileSyncJob.perform_now(user.id)

    assert_predicate old_email.reload, :source_signing_in?
    assert_predicate user.email_addresses.find_by!(email: "new@example.com"), :source_slack?
  end

  test "promotes an already-linked sign-in email when Slack changes to it" do
    user = User.create!(timezone: "UTC", slack_uid: "U_EXISTING_EMAIL_SYNC")
    old_email = user.email_addresses.create!(email: "old@example.com", source: :slack)
    new_email = user.email_addresses.create!(email: "new@example.com", source: :signing_in)
    stub_request(:get, "https://slack.com/api/users.info?user=U_EXISTING_EMAIL_SYNC")
      .to_return(body: {
        ok: true,
        user: {
          name: "existing-email-sync",
          profile: { email: "new@example.com" }
        }
      }.to_json)

    SlackProfileSyncJob.perform_now(user.id)

    assert_predicate old_email.reload, :source_signing_in?
    assert_predicate new_email.reload, :source_slack?
  end

  test "does not claim a Slack email linked to another account" do
    user = User.create!(timezone: "UTC", slack_uid: "U_EMAIL_CONFLICT")
    old_email = user.email_addresses.create!(email: "old@example.com", source: :slack)
    other_user = User.create!(timezone: "UTC")
    other_email = other_user.email_addresses.create!(email: "taken@example.com", source: :signing_in)
    stub_request(:get, "https://slack.com/api/users.info?user=U_EMAIL_CONFLICT")
      .to_return(body: {
        ok: true,
        user: {
          name: "email-conflict",
          profile: { email: "taken@example.com" }
        }
      }.to_json)

    assert_raises(SlackIntegration::EmailConflictError) do
      SlackProfileSyncJob.perform_now(user.id)
    end

    assert_predicate old_email.reload, :source_slack?
    assert_equal other_user, other_email.reload.user
    assert_nil user.reload.slack_synced_at
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
end
