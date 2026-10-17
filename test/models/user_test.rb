require "test_helper"
require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)

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
    first_user = create(:user, username: "duplicate_name")
    create(:user, username: "other_name")
      .update_column(:username, "DUPLICATE_NAME")

    assert_nothing_raised do
      first_user.update!(admin_level: :ultraadmin)
    end

    assert_equal "ultraadmin", first_user.reload.admin_level
  end

  test "impersonation follows the admin hierarchy" do
    users = %i[default viewer admin superadmin ultraadmin].to_h do |level|
      [ level, level == :default ? create(:user) : create(:user, level) ]
    end

    assert users[:admin].can_impersonate?(users[:default])
    assert users[:admin].can_impersonate?(users[:viewer])
    assert users[:superadmin].can_impersonate?(users[:admin])
    assert users[:ultraadmin].can_impersonate?(users[:superadmin])
    assert_not users[:ultraadmin].can_impersonate?(users[:ultraadmin])
    assert_not users[:default].can_impersonate?(users[:default])
  end

  test "rotate_api_keys! replaces existing api key with a new one" do
    user = create(:user, slack_uid: "U#{SecureRandom.hex(8)}")
    create(:api_key, user: user, name: "Original key")
    original_token = user.api_keys.first.token

    new_api_key = user.rotate_api_keys!

    assert_equal user.id, new_api_key.user_id
    assert_equal "Hackatime key", new_api_key.name
    assert_nil ApiKey.find_by(token: original_token)
  end

  test "rotate_api_keys! creates a key when none exists" do
    user = create(:user, slack_uid: "U#{SecureRandom.hex(8)}")

    assert_equal 0, user.api_keys.count

    new_api_key = user.rotate_api_keys!

    assert_equal user.id, new_api_key.user_id
    assert_equal "Hackatime key", new_api_key.name
    assert_equal [ new_api_key.id ], user.api_keys.reload.pluck(:id)
  end

  test "flipper id uses the user id" do
    user = create(:user)

    assert_equal "User;#{user.id}", user.flipper_id
  end

  test "api_access_restricted? is true for red users and users pending deletion" do
    user = create(:user)
    assert_not user.api_access_restricted?

    user.update!(trust_level: :red)
    assert user.api_access_restricted?

    user.update!(trust_level: :blue)
    assert_not user.api_access_restricted?

    DeletionRequest.create_for_user!(user)
    assert user.api_access_restricted?
  end

  test "display name override takes precedence over synced provider names" do
    user = create(:user,
      username: "profile_user",
      slack_username: "slack_user",
      github_username: "github_user",
      display_name_override: "Custom Name"
    )

    assert_equal "Custom Name", user.display_name
  end

  test "display name override is normalized before validation" do
    user = create(:user, slack_username: "slack_user", display_name_override: "  Custom Name  ")

    assert_equal "Custom Name", user.display_name_override
  end

  test "slack profile sync does not replace display name override" do
    user = create(:user,
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
    user = create(:user, slack_uid: "U_HCA", slack_access_token: "personal-token")
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

  test "Slack authentication removes a superseded Slack email" do
    user = User.create!(timezone: "UTC", slack_uid: "U_EMAIL_CHANGE")
    old_email = user.email_addresses.create!(email: "old@example.com", source: :slack)
    new_email = user.email_addresses.create!(email: "new@example.com", source: :signing_in)
    stub_request(:post, "https://slack.com/api/oauth.v2.access")
      .to_return(body: {
        ok: true,
        authed_user: {
          id: "U_EMAIL_CHANGE",
          access_token: "slack-token",
          scope: "users:read,users:read.email"
        }
      }.to_json)
    stub_request(:get, "https://slack.com/api/users.info?user=U_EMAIL_CHANGE")
      .with(headers: { "Authorization" => "Bearer slack-token" })
      .to_return(body: {
        ok: true,
        user: {
          name: "email-change",
          tz: "UTC",
          profile: { email: new_email.email }
        }
      }.to_json)

    authenticated_user = User.from_slack_token("code", "https://example.com/auth/slack/callback")

    assert_equal user, authenticated_user
    assert_not EmailAddress.exists?(old_email.id)
    assert_predicate new_email.reload, :source_slack?
  end

  test "Slack authentication restores email changes when the user cannot be saved" do
    user = User.create!(timezone: "UTC", slack_uid: "U_ORIGINAL")
    old_email = user.email_addresses.create!(email: "old@example.com", source: :slack)
    new_email = user.email_addresses.create!(email: "new@example.com", source: :signing_in)
    User.create!(timezone: "UTC", slack_uid: "U_CONFLICT")
    stub_request(:post, "https://slack.com/api/oauth.v2.access")
      .to_return(body: {
        ok: true,
        authed_user: {
          id: "U_CONFLICT",
          access_token: "slack-token",
          scope: "users:read,users:read.email"
        }
      }.to_json)
    stub_request(:get, "https://slack.com/api/users.info?user=U_CONFLICT")
      .with(headers: { "Authorization" => "Bearer slack-token" })
      .to_return(body: {
        ok: true,
        user: {
          name: "email-change",
          tz: "UTC",
          profile: { email: new_email.email }
        }
      }.to_json)

    assert_nil User.from_slack_token("code", "https://example.com/auth/slack/callback")

    assert_predicate old_email.reload, :source_slack?
    assert_predicate new_email.reload, :source_signing_in?
    assert_equal "U_ORIGINAL", user.reload.slack_uid
  end

  test "HCA authentication fills a missing Slack ID on an existing account" do
    user = create(:user, hca_id: "hca-existing")
    stub_request(:post, "https://hca.dinosaurbbq.org/oauth/token")
      .to_return(body: { access_token: "hca-token" }.to_json)
    stub_request(:get, "https://hca.dinosaurbbq.org/api/v1/me")
      .with(headers: { "Authorization" => "Bearer hca-token" })
      .to_return(body: {
        identity: { id: "hca-existing", slack_id: "U_FROM_HCA" },
        scopes: %w[email slack_id]
      }.to_json)

    authenticated_user = nil
    assert_enqueued_with(job: SlackProfileSyncJob, args: [ user.id ]) do
      authenticated_user = User.from_hca_token("code", "https://example.com/auth/hca/callback")
    end

    assert_equal user, authenticated_user
    assert_equal "U_FROM_HCA", user.reload.slack_uid
  end

  test "HCA authentication does not replace an existing Slack ID" do
    user = create(:user,
      hca_id: "hca-linked",
      slack_uid: "U_LINKED",
      slack_synced_at: 1.hour.ago
    )
    stub_request(:post, "https://hca.dinosaurbbq.org/oauth/token")
      .to_return(body: { access_token: "hca-token" }.to_json)
    stub_request(:get, "https://hca.dinosaurbbq.org/api/v1/me")
      .with(headers: { "Authorization" => "Bearer hca-token" })
      .to_return(body: {
        identity: { id: "hca-linked", slack_id: "U_DIFFERENT" },
        scopes: %w[email slack_id]
      }.to_json)

    authenticated_user = nil
    assert_enqueued_with(job: SlackProfileSyncJob, args: [ user.id ]) do
      authenticated_user = User.from_hca_token("code", "https://example.com/auth/hca/callback")
    end

    assert_equal user, authenticated_user
    assert_equal "U_LINKED", user.reload.slack_uid
  end

  test "HCA authentication does not claim a Slack ID linked to another account" do
    user = create(:user, hca_id: "hca-unlinked")
    create(:user, slack_uid: "U_ALREADY_LINKED")
    stub_request(:post, "https://hca.dinosaurbbq.org/oauth/token")
      .to_return(body: { access_token: "hca-token" }.to_json)
    stub_request(:get, "https://hca.dinosaurbbq.org/api/v1/me")
      .with(headers: { "Authorization" => "Bearer hca-token" })
      .to_return(body: {
        identity: { id: "hca-unlinked", slack_id: "U_ALREADY_LINKED" },
        scopes: %w[email slack_id]
      }.to_json)

    authenticated_user = User.from_hca_token("code", "https://example.com/auth/hca/callback")

    assert_equal user, authenticated_user
    assert_nil user.reload.slack_uid
  end

  test "creating a user with an email address queues a welcome email" do
    email = "welcome-#{SecureRandom.hex(4)}@example.com"

    assert_enqueued_email_with OnboardingMailer, :welcome, args: ->(args) { args.second[:recipient_email] == email } do
      User.transaction do
        user = create(:user)
        create(:email_address, user: user, email: email, source: :signing_in)
      end
    end
  end

  test "active heartbeat import run counts all import sources" do
    user = create(:user)

    assert_not user.active_heartbeat_import_run?

    other_user = create(:user)
    create(:heartbeat_import_run, user: other_user,
      source_kind: :dev_upload,
      state: :queued,
      source_filename: "dev.json"
    )
    assert other_user.active_heartbeat_import_run?

    create(:heartbeat_import_run, user: user,
      source_kind: :wakatime_dump,
      state: :waiting_for_dump,
      encrypted_api_key: "secret"
    )

    assert user.active_heartbeat_import_run?
  end

  test "set_leaderboard_shadowban requires privileged actor and reason" do
    actor = create(:user, :superadmin)
    user = create(:user, username: "shadowban_target")

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
    actor = create(:user, :superadmin)
    user = create(:user, username: "shadowban_expiring")
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
    actor = create(:user, :superadmin)
    user = create(:user, username: "shadowban_past_exp")

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
    actor = create(:user, :superadmin)
    user = create(:user, username: "sb_exp_update")
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
    actor = create(:user, :superadmin)
    user = create(:user, username: "pt_shadowban_target")

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
    actor = create(:user, :superadmin)
    peer = create(:user, :superadmin)

    assert_not actor.set_leaderboard_shadowban(banned: true, changed_by_user: actor, reason: "self")
    assert_not peer.set_leaderboard_shadowban(banned: true, changed_by_user: actor, reason: "peer")
  end

  test "changing timezone invalidates activity graph caches and schedules a dashboard rollup refresh" do
    with_memory_cache_store do
      Rails.cache.clear

      user = create(:user)
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
