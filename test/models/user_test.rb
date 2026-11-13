require "test_helper"
require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)

module HCAIdentityStub
  private

  def stub_hca_identity(identity)
    stub_request(:post, "https://hca.dinosaurbbq.org/oauth/token")
      .to_return(body: { access_token: "hca-token" }.to_json)
    stub_request(:get, "https://hca.dinosaurbbq.org/api/v1/me")
      .with(headers: { "Authorization" => "Bearer hca-token" })
      .to_return(body: hca_me_response(identity).to_json)
  end

  def hca_me_response(identity) = { "identity" => identity.stringify_keys, "scopes" => %w[email slack_id] }
end

class UserTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper
  include HCAIdentityStub

  setup do
    clear_enqueued_jobs
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
  end

  teardown do
    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  test "timezone validation preserves IANA identifiers and rejects unknown values" do
    user = create(:user)
    [ "UTC", "America/New_York", "Asia/Kathmandu" ].each do |timezone|
      user.update!(timezone: timezone)
      assert_equal timezone, user.reload.timezone
    end

    [ nil, "", "Unknown/Timezone" ].each do |timezone|
      assert_not user.update(timezone: timezone)
      assert_includes user.errors[:timezone], "is not included in the list"
      assert_equal "Asia/Kathmandu", user.reload.timezone
    end
  end

  test "parses Rails timezone names into persistable IANA identifiers" do
    user = create(:user)
    user.parse_and_set_timezone("Eastern Time (US & Canada)")
    assert_equal "America/New_York", user.timezone
    user.save!
    assert_equal "America/New_York", user.reload.timezone
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

  test "profile sync uses Cachet without a Slack token and falls back to the real name" do
    user = create(:user, slack_uid: "U_HCA", display_name_override: "Custom Name")
    original_token = ENV["SLACK_USER_OAUTH_TOKEN"]
    ENV.delete("SLACK_USER_OAUTH_TOKEN")
    stub_request(:get, "https://cachet.hackclub.com/users/U_HCA")
      .with { |request| !request.headers.key?("Authorization") }
      .to_return(body: {
        displayName: " ",
        realName: "Real Name",
        imageUrl: "https://example.com/hca-avatar.png"
      }.to_json)

    user.update_from_cachet
    user.save!

    user.reload
    assert_equal "Real Name", user.slack_username
    assert_equal "https://example.com/hca-avatar.png", user.slack_avatar_url
    assert_equal "Custom Name", user.display_name
    assert_not_nil user.slack_synced_at
  ensure
    ENV["SLACK_USER_OAUTH_TOKEN"] = original_token
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

  test "HCA authentication links an unlinked account by email regardless of case" do
    user = create(:user)
    create(:email_address, user: user, email: "mixed-case@example.com")
    stub_hca_identity(id: "hca-mixed", primary_email: "Mixed-Case@Example.com")

    assert_no_difference "User.count" do
      assert_equal user, User.from_hca_token("code", "https://example.com/auth/hca/callback")
    end
    assert_equal "hca-mixed", user.reload.hca_id
  end

  test "HCA authentication refuses an email that belongs to another identity's account" do
    user = create(:user, hca_id: "hca-original")
    create(:email_address, user: user, email: "shared@example.com")
    stub_hca_identity(id: "hca-other", primary_email: "shared@example.com")

    assert_no_difference "User.count" do
      assert_raises(OauthAuthentication::HCAIdentityConflictError) do
        User.from_hca_token("code", "https://example.com/auth/hca/callback")
      end
    end
    assert_equal "hca-original", user.reload.hca_id
  end

  test "HCA authentication refuses a Slack ID that belongs to another identity's account" do
    user = create(:user, hca_id: "hca-original", slack_uid: "U_SHARED")
    stub_hca_identity(id: "hca-other", slack_id: "U_SHARED", primary_email: "fresh@example.com")

    assert_no_difference [ "User.count", "EmailAddress.count" ] do
      assert_raises(OauthAuthentication::HCAIdentityConflictError) do
        User.from_hca_token("code", "https://example.com/auth/hca/callback")
      end
    end
    assert_equal "hca-original", user.reload.hca_id
  end

  test "HCA authentication prefers an unlinked email match over a Slack ID on another identity's account" do
    create(:user, hca_id: "hca-original", slack_uid: "U_SHARED")
    unlinked = create(:user)
    create(:email_address, user: unlinked, email: "unlinked@example.com")
    stub_hca_identity(id: "hca-other", slack_id: "U_SHARED", primary_email: "unlinked@example.com")

    assert_equal unlinked, User.from_hca_token("code", "https://example.com/auth/hca/callback")
    assert_equal "hca-other", unlinked.reload.hca_id
    assert_nil unlinked.slack_uid
  end

  test "HCA authentication does not reuse the previous sign-in when an identity has no ID" do
    previous = create(:user, hca_id: "hca-previous")
    stub_hca_identity(id: "hca-previous")
    assert_equal previous, User.from_hca_token("code", "https://example.com/auth/hca/callback")

    stub_hca_identity(id: nil)

    assert_nil User.from_hca_token("code", "https://example.com/auth/hca/callback")
    assert_equal "hca-previous", previous.reload.hca_id
  end

  test "linking an HCA identity attaches it and its Slack ID to an unlinked account" do
    user = create(:user)

    user.link_hca_identity!("hca-token", hca_me_response(id: "hca-new", slack_id: "U_LINKED"))

    user.reload
    assert_equal "hca-new", user.hca_id
    assert_equal "hca-token", user.hca_access_token
    assert_equal "U_LINKED", user.slack_uid
  end

  test "linking moves an identity off an unused account and deletes that account" do
    user = create(:user)
    create(:heartbeat, user: user)
    unused = create(:user, hca_id: "hca-moving", slack_uid: "U_MOVING")
    create(:email_address, user: unused, email: "moving@example.com")

    assert_no_difference "User.count" do
      user.link_hca_identity!("hca-token", hca_me_response(id: "hca-moving", slack_id: "U_MOVING"))
    end

    user.reload
    assert_equal "hca-moving", user.hca_id
    assert_equal "U_MOVING", user.slack_uid
    unused.reload
    assert_nil unused.hca_id
    assert_nil unused.slack_uid
    assert_equal "deleted_user_#{unused.id}", unused.username
    assert unused.email_addresses.all?(&:source_preserved_for_deletion?)
  end

  test "linking refuses an identity whose account is in use" do
    in_use = {
      "has coding time" => ->(holder) { create(:heartbeat, user: holder) },
      "has deleted coding time" => ->(holder) { create(:heartbeat, user: holder).soft_delete },
      "owns an OAuth app" => ->(holder) { create(:oauth_application, owner: holder) },
      "is importing coding time" => ->(holder) { create(:heartbeat_import_run, user: holder, source_kind: :dev_upload, state: :queued, source_filename: "dev.json") },
      "is an admin" => ->(holder) { holder.update!(admin_level: :admin) }
    }

    in_use.each_with_index do |(reason, use), index|
      user = create(:user)
      holder = create(:user, hca_id: "hca-held-#{index}")
      use.call(holder)

      assert_raises(OauthAuthentication::HCAIdentityConflictError, reason) do
        user.link_hca_identity!("hca-token", hca_me_response(id: "hca-held-#{index}"))
      end
      assert_nil user.reload.hca_id, reason
      assert_equal "hca-held-#{index}", holder.reload.hca_id, reason
      assert_nil holder.username, reason
    end
  end

  test "linking refuses an account that already has another identity" do
    user = create(:user, hca_id: "hca-original")

    assert_raises(OauthAuthentication::HCAIdentityConflictError) do
      user.link_hca_identity!("hca-token", hca_me_response(id: "hca-other"))
    end
    assert_equal "hca-original", user.reload.hca_id
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

class UserHCASignInConcurrencyTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include HCAIdentityStub

  self.use_transactional_tests = false

  setup do
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    @suffix = SecureRandom.hex(4)
    @users = []
  end

  teardown do
    User.where(id: @users.map(&:id)).find_each(&:destroy!)
    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  test "an account another identity claims during sign-in is not linked to a second identity" do
    email = "overlap-#{@suffix}@example.com"
    @users << (user = create(:user))
    create(:email_address, user: user, email: email)
    stub_hca_identity(id: "hca-second-#{@suffix}", primary_email: email)

    assert_raises(OauthAuthentication::HCAIdentityConflictError) do
      sign_in_behind_uncommitted_write { User.find(user.id).update!(hca_id: "hca-first-#{@suffix}") }
    end
    assert_equal "hca-first-#{@suffix}", user.reload.hca_id
  end

  test "an identity that signs up twice at once gets one account" do
    hca_id = "hca-twice-#{@suffix}"
    stub_hca_identity(id: hca_id)

    first = nil
    signed_in = sign_in_behind_uncommitted_write { @users << (first = create(:user, hca_id: hca_id)) }

    assert_equal first, signed_in
    assert_equal 1, User.where(hca_id: hca_id).count
  end

  private

  # Signs in while another connection holds an uncommitted write, which commits
  # only once the sign-in is waiting on it.
  def sign_in_behind_uncommitted_write(&write)
    written = Queue.new
    commit = Queue.new
    writer = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        User.transaction do
          write.call
          written << true
          commit.pop
        end
      end
    end
    Timeout.timeout(10) { written.pop }

    signer = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        User.from_hca_token("code", "https://example.com/auth/hca/callback").tap { |user| @users << user if user }
      end
    end
    signer.report_on_exception = false
    Timeout.timeout(10) { sleep 0.01 until waiting_on_lock? || !signer.alive? }
    commit << true
    Timeout.timeout(10) { writer.value }
    Timeout.timeout(10) { signer.value }
  ensure
    commit << true
    [ writer, signer ].each { |thread| thread&.join(10) }
  end

  def waiting_on_lock?
    User.uncached do
      User.connection.select_value(<<~SQL).positive?
        SELECT count(*) FROM pg_stat_activity WHERE datname = current_database() AND wait_event_type = 'Lock'
      SQL
    end
  end
end
