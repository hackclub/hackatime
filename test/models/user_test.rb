require "test_helper"
require "webmock/minitest"

class UserTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  setup do
    clear_enqueued_jobs
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
  end

  teardown do
    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  test "theme options include all supported themes in order" do
    values = User.theme_options.map { |option| option[:value] }

    assert_equal User.themes.keys, values
  end

  test "theme metadata falls back to default for unknown themes" do
    metadata = User.theme_metadata("not-a-real-theme")

    assert_equal "neon", metadata[:value]
  end

  test "updating admin level does not validate existing duplicate usernames" do
    first_user = User.create!(timezone: "UTC", username: "duplicate_name")
    User.create!(timezone: "UTC", username: "other_name")
      .update_column(:username, "DUPLICATE_NAME")

    assert_nothing_raised do
      first_user.update!(admin_level: :ultraadmin)
    end

    assert_equal "ultraadmin", first_user.reload.admin_level
  end

  test "rotate_api_keys! replaces existing api key with a new one" do
    user = User.create!(timezone: "UTC", slack_uid: "U#{SecureRandom.hex(8)}")
    user.api_keys.create!(name: "Original key")
    original_token = user.api_keys.first.token

    new_api_key = user.rotate_api_keys!

    assert_equal user.id, new_api_key.user_id
    assert_equal "Hackatime key", new_api_key.name
    assert_nil ApiKey.find_by(token: original_token)
  end

  test "rotate_api_keys! creates a key when none exists" do
    user = User.create!(timezone: "UTC", slack_uid: "U#{SecureRandom.hex(8)}")

    assert_equal 0, user.api_keys.count

    new_api_key = user.rotate_api_keys!

    assert_equal user.id, new_api_key.user_id
    assert_equal "Hackatime key", new_api_key.name
    assert_equal [ new_api_key.id ], user.api_keys.reload.pluck(:id)
  end

  test "flipper id uses the user id" do
    user = User.create!(timezone: "UTC")

    assert_equal "User;#{user.id}", user.flipper_id
  end

  test "api_access_restricted? is true for red users and users pending deletion" do
    user = User.create!(timezone: "UTC")
    assert_not user.api_access_restricted?

    user.update!(trust_level: :red)
    assert user.api_access_restricted?

    user.update!(trust_level: :blue)
    assert_not user.api_access_restricted?

    DeletionRequest.create_for_user!(user)
    assert user.api_access_restricted?
  end

  test "anonymized users cannot authenticate or access APIs" do
    user = User.create!(timezone: "UTC", anonymized_at: Time.current)

    assert user.anonymized?
    assert_not user.authentication_allowed?
    assert user.api_access_restricted?
  end

  test "display name override takes precedence over synced provider names" do
    user = User.create!(
      timezone: "UTC",
      username: "profile_user",
      slack_username: "slack_user",
      github_username: "github_user",
      display_name_override: "Custom Name"
    )

    assert_equal "Custom Name", user.display_name
  end

  test "display name override is normalized before validation" do
    user = User.create!(timezone: "UTC", slack_username: "slack_user", display_name_override: "  Custom Name  ")

    assert_equal "Custom Name", user.display_name_override
  end

  test "slack profile sync does not replace display name override" do
    user = User.create!(
      timezone: "UTC",
      slack_username: "old_slack",
      display_name_override: "Custom Name"
    )

    user.apply_slack_profile_attributes({
      "name" => "fallback",
      "profile" => {
        "display_name_normalized" => "new_slack",
        "real_name_normalized" => "Real Name",
        "image_192" => "https://example.com/avatar.png"
      }
    })
    user.save!

    assert_equal "new_slack", user.reload.slack_username
    assert_equal "Custom Name", user.display_name_override
    assert_equal "Custom Name", user.display_name
  end

  test "slack profile sync prefers the workspace token over the user's Slack token" do
    user = User.create!(timezone: "UTC", slack_uid: "U_HCA", slack_access_token: "personal-token")
    original_token = ENV["SLACK_USER_OAUTH_TOKEN"]
    ENV["SLACK_USER_OAUTH_TOKEN"] = "workspace-token"
    request = stub_request(:get, "https://slack.com/api/users.info?user=U_HCA")
      .with(headers: { "Authorization" => "Bearer workspace-token" })
      .to_return(body: {
        ok: true,
        user: {
          name: "hca-user",
          profile: { image_192: "https://example.com/hca-avatar.png" }
        }
      }.to_json)

    user.update_from_slack
    user.save!

    assert_requested request
    assert_equal "https://example.com/hca-avatar.png", user.reload.slack_avatar_url
  ensure
    ENV["SLACK_USER_OAUTH_TOKEN"] = original_token
  end

  test "HCA authentication fills a missing Slack ID on an existing account" do
    user = User.create!(timezone: "UTC", hca_id: "ident!hca-existing")

    authenticated_user = nil
    assert_enqueued_with(job: SlackProfileSyncJob, args: [ user.id ]) do
      authenticated_user = User.from_hca_identity(
        subject: "ident!hca-existing",
        email: "hca-existing@example.com",
        slack_uid: "U_FROM_HCA"
      )
    end

    assert_equal user, authenticated_user
    assert_equal "U_FROM_HCA", user.reload.slack_uid
  end

  test "HCA authentication does not replace an existing Slack ID" do
    user = User.create!(
      timezone: "UTC",
      hca_id: "ident!hca-linked",
      slack_uid: "U_LINKED",
      slack_synced_at: 1.hour.ago
    )

    authenticated_user = nil
    assert_enqueued_with(job: SlackProfileSyncJob, args: [ user.id ]) do
      authenticated_user = User.from_hca_identity(
        subject: "ident!hca-linked",
        email: "hca-linked@example.com",
        slack_uid: "U_DIFFERENT"
      )
    end

    assert_equal user, authenticated_user
    assert_equal "U_LINKED", user.reload.slack_uid
  end

  test "HCA authentication does not claim a Slack ID linked to another account" do
    user = User.create!(timezone: "UTC", hca_id: "ident!hca-unlinked")
    User.create!(timezone: "UTC", slack_uid: "U_ALREADY_LINKED")

    authenticated_user = User.from_hca_identity(
      subject: "ident!hca-unlinked",
      email: "hca-unlinked@example.com",
      slack_uid: "U_ALREADY_LINKED"
    )

    assert_equal user, authenticated_user
    assert_nil user.reload.slack_uid
  end

  test "HCA authentication links a Slack-matched legacy account when the HCA email differs" do
    user = User.create!(timezone: "UTC", slack_uid: "U_MATCHED")
    user.email_addresses.create!(email: "old-slack-email@example.com", source: :slack)

    authenticated_user = User.from_hca_identity(
      subject: "ident!different-email",
      email: "current-hca-email@example.com",
      slack_uid: "U_MATCHED"
    )

    assert_equal user, authenticated_user
    assert_equal "ident!different-email", user.reload.hca_id
    assert user.email_addresses.exists?(email: "old-slack-email@example.com")
    assert user.email_addresses.source_hca.exists?(email: "current-hca-email@example.com")
  end

  test "HCA authentication rejects split email and Slack candidates" do
    email_user = User.create!(timezone: "UTC")
    email_user.email_addresses.create!(email: "split@example.com", source: :signing_in)
    slack_user = User.create!(timezone: "UTC", slack_uid: "U_SPLIT")

    error = assert_raises(OauthAuthentication::HcaIdentityConflictError) do
      User.from_hca_identity(
        subject: "ident!split",
        email: "split@example.com",
        slack_uid: "U_SPLIT"
      )
    end

    assert_equal "split_identity", error.reason
    assert_equal email_user.id, error.email_user_id
    assert_equal slack_user.id, error.slack_user_id
    assert_nil email_user.reload.hca_id
    assert_nil slack_user.reload.hca_id
  end

  test "HCA authentication rejects a legacy candidate already linked to another subject" do
    user = User.create!(timezone: "UTC", hca_id: "ident!existing")
    user.email_addresses.create!(email: "already-linked@example.com", source: :hca)

    error = assert_raises(OauthAuthentication::HcaIdentityConflictError) do
      User.from_hca_identity(
        subject: "ident!different",
        email: "already-linked@example.com"
      )
    end

    assert_equal "subject_already_linked", error.reason
    assert_equal "ident!existing", user.reload.hca_id
  end

  test "HCA authentication returns nil when no legacy identity matches" do
    assert_nil User.from_hca_identity(
      subject: "ident!unmatched",
      email: "unmatched@example.com",
      slack_uid: "U_UNMATCHED"
    )
  end

  test "HCA authentication rejects anonymized identity candidates" do
    user = User.create!(timezone: "UTC", anonymized_at: Time.current)
    user.email_addresses.create!(email: "preserved@example.com", source: :preserved_for_deletion)

    error = assert_raises(OauthAuthentication::HcaIdentityConflictError) do
      User.from_hca_identity(subject: "ident!deleted", email: "preserved@example.com")
    end

    assert_equal "anonymized", error.reason
    assert_nil user.reload.hca_id
  end

  test "Slack integration does not restore identity after a stale user is anonymized" do
    user = User.create!(timezone: "UTC", hca_id: "ident!slack-race")
    stale_user = User.find(user.id)
    AnonymizeUserService.call(user)

    connected = User.connect_slack_identity!(stale_user, {
      uid: "U_AFTER_DELETION",
      access_token: "slack-access-token",
      scopes: [ "users:read" ],
      profile: { "name" => "restored" }
    })

    assert_not connected
    assert_nil user.reload.slack_uid
    assert_nil user.slack_access_token
  end

  test "Slack integration rejects users with a pending deletion" do
    user = User.create!(timezone: "UTC", hca_id: "ident!slack-pending-deletion")
    DeletionRequest.create_for_user!(user)

    connected = User.connect_slack_identity!(user, {
      uid: "U_PENDING_DELETION",
      access_token: "slack-access-token",
      scopes: [ "users:read" ],
      profile: { "name" => "pending" }
    })

    assert_not connected
    assert_nil user.reload.slack_uid
    assert_nil user.slack_access_token
  end

  test "creating a user with an email address queues a welcome email" do
    email = "welcome-#{SecureRandom.hex(4)}@example.com"

    assert_enqueued_email_with OnboardingMailer, :welcome, args: ->(args) { args.second[:recipient_email] == email } do
      User.transaction do
        user = User.create!(timezone: "UTC")
        user.email_addresses.create!(email: email, source: :signing_in)
      end
    end
  end

  test "active remote heartbeat import run only counts remote imports" do
    user = User.create!(timezone: "UTC")

    assert_not user.active_remote_heartbeat_import_run?

    # An active non-remote (dev_upload) import should not count as a remote import.
    # Use a separate user because the unique index prevents two active imports per user.
    other_user = User.create!(timezone: "UTC")
    other_user.heartbeat_import_runs.create!(
      source_kind: :dev_upload,
      state: :queued,
      source_filename: "dev.json"
    )
    assert_not other_user.active_remote_heartbeat_import_run?

    user.heartbeat_import_runs.create!(
      source_kind: :wakatime_dump,
      state: :waiting_for_dump,
      encrypted_api_key: "secret"
    )

    assert user.active_remote_heartbeat_import_run?
  end

  test "set_leaderboard_shadowban requires privileged actor and reason" do
    actor = User.create!(timezone: "UTC", admin_level: :superadmin)
    user = User.create!(timezone: "UTC", username: "shadowban_target")

    assert_not user.set_leaderboard_shadowban(banned: true, changed_by_user: actor, reason: "")
    assert_includes user.errors[:leaderboard_shadowban_reason], "can't be blank"
    assert_not user.reload.leaderboard_shadowbanned?

    assert user.set_leaderboard_shadowban(banned: true, changed_by_user: actor, reason: "fake time")
    assert user.reload.leaderboard_shadowbanned?
    assert_equal "fake time", user.leaderboard_shadowban_reason
    assert_equal actor, user.leaderboard_shadowbanned_by
    assert_nil user.leaderboard_shadowban_expires_at

    assert user.set_leaderboard_shadowban(banned: false, changed_by_user: actor)
    assert_not user.reload.leaderboard_shadowbanned?
    assert_nil user.leaderboard_shadowban_reason
    assert_nil user.leaderboard_shadowbanned_by
    assert_nil user.leaderboard_shadowban_expires_at
  end

  test "set_leaderboard_shadowban can schedule an automatic expiration" do
    actor = User.create!(timezone: "UTC", admin_level: :superadmin)
    user = User.create!(timezone: "UTC", username: "shadowban_expiring")
    expires_at = 2.days.from_now

    assert_enqueued_with(job: LeaderboardShadowbanExpirationJob, args: [ user.id ], at: expires_at) do
      assert user.set_leaderboard_shadowban(
        banned: true,
        changed_by_user: actor,
        reason: "temporary fake time",
        expires_at: expires_at
      )
    end

    assert_equal expires_at.to_i, user.reload.leaderboard_shadowban_expires_at.to_i
  end

  test "set_leaderboard_shadowban requires future automatic expiration" do
    actor = User.create!(timezone: "UTC", admin_level: :superadmin)
    user = User.create!(timezone: "UTC", username: "shadowban_past_exp")

    assert_not user.set_leaderboard_shadowban(
      banned: true,
      changed_by_user: actor,
      reason: "temporary fake time",
      expires_at: 1.minute.ago
    )
    assert_includes user.errors[:leaderboard_shadowban_expires_at], "must be in the future"
    assert_not user.reload.leaderboard_shadowbanned?
  end

  test "expired leaderboard shadowban does not block unrelated user updates" do
    actor = User.create!(timezone: "UTC", admin_level: :superadmin)
    user = User.create!(timezone: "UTC", username: "sb_exp_update")
    expires_at = 1.minute.from_now

    assert user.set_leaderboard_shadowban(
      banned: true,
      changed_by_user: actor,
      reason: "temporary fake time",
      expires_at: expires_at
    )

    travel_to 2.minutes.from_now do
      assert user.update(username: "sb_exp_update"), user.errors.full_messages.to_sentence
    end
  end

  test "set_leaderboard_shadowban records PaperTrail changes" do
    actor = User.create!(timezone: "UTC", admin_level: :superadmin)
    user = User.create!(timezone: "UTC", username: "pt_shadowban_target")

    assert_difference -> { PaperTrail::Version.where(item_type: "User", item_id: user.id).count }, 1 do
      PaperTrail.request(whodunnit: actor.id) do
        assert user.set_leaderboard_shadowban(banned: true, changed_by_user: actor, reason: "leaderboard abuse")
      end
    end

    version = PaperTrail::Version.where(item_type: "User", item_id: user.id).last
    assert_equal actor.id.to_s, version.whodunnit
    assert_includes version.object_changes, "leaderboard_shadowbanned"
  end

  test "set_leaderboard_shadowban cannot target self or equal rank admins" do
    actor = User.create!(timezone: "UTC", admin_level: :superadmin)
    peer = User.create!(timezone: "UTC", admin_level: :superadmin)

    assert_not actor.set_leaderboard_shadowban(banned: true, changed_by_user: actor, reason: "self")
    assert_not peer.set_leaderboard_shadowban(banned: true, changed_by_user: actor, reason: "peer")
  end

  test "changing timezone invalidates activity graph caches and schedules a dashboard rollup refresh" do
    with_memory_cache_store do
      Rails.cache.clear

      user = User.create!(timezone: "UTC")
      Rails.cache.write(user.activity_graph_cache_key("UTC"), { "2026-04-14" => 60 })
      Rails.cache.write(user.activity_graph_cache_key("America/New_York"), { "2026-04-14" => 60 })

      assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ]) do
        user.update!(timezone: "America/New_York")
      end

      assert_not Rails.cache.exist?(user.activity_graph_cache_key("UTC"))
      assert_not Rails.cache.exist?(user.activity_graph_cache_key("America/New_York"))
    end
  end

  private

  def with_memory_cache_store
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache.lookup_store(:memory_store)
    yield
  ensure
    Rails.cache = original_cache
  end
end
