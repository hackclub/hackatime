require "test_helper"

class Admin::AccountMergerControllerTest < ActionDispatch::IntegrationTest
  class RejectingQueueAdapter
    def enqueue(_job) = raise ActiveJob::EnqueueError, "queue unavailable"
    def enqueue_at(_job, _timestamp) = raise ActiveJob::EnqueueError, "queue unavailable"
  end

  setup do
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    enqueued_jobs.clear
  end

  teardown do
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  test "search_users returns formatted user results" do
    admin = User.create!(timezone: "UTC", admin_level: :ultraadmin)
    user = User.create!(timezone: "UTC", username: "merge_target")
    user.email_addresses.create!(email: "merge-target@example.com", source: :signing_in)
    sign_in_as(admin)

    get search_users_admin_account_merger_path, params: { query: "merge_target" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body.length
    assert_equal user.id, body.first["id"]
    assert_equal user.display_name, body.first["display_name"]
    assert_equal user.avatar_url, body.first["avatar_url"]
    assert_equal user.username, body.first["username"]
    assert_equal "merge-target@example.com", body.first["email"]
    assert_equal user.created_at.strftime("%Y-%m-%d"), body.first["created_at"]
  end

  test "merge does not double count revoked doorkeeper rows in success message" do
    admin = User.create!(timezone: "UTC", admin_level: :ultraadmin)
    older = User.create!(timezone: "UTC", username: "older_user")
    newer = User.create!(timezone: "UTC", username: "newer_user")
    sign_in_as(admin)

    heartbeat = create_heartbeat(user: newer, time: Time.current.to_i, source_type: :test_entry)
    api_key = ApiKey.create!(user: newer, name: "Merge Test Key")
    newer.email_addresses.create!(email: "newer@example.com", source: :signing_in)
    newer.sign_in_tokens.create!(auth_type: :email)
    oauth_app = newer.oauth_applications.create!(
      name: "Merge Test App",
      redirect_uri: "https://example.com/callback",
      scopes: "profile",
      confidential: true
    )
    Doorkeeper::AccessToken.create!(
      application: oauth_app,
      resource_owner_id: newer.id,
      scopes: "profile",
      expires_in: 1.hour.to_i
    )
    Doorkeeper::AccessGrant.create!(
      application: oauth_app,
      resource_owner_id: newer.id,
      redirect_uri: oauth_app.redirect_uri,
      scopes: "profile",
      expires_in: 10.minutes.to_i
    )

    ActiveJob::Base.queue_adapter = :good_job
    jobs = GoodJob::Job.where(job_class: "HeartbeatAccountMergeJob")
    assert_difference -> { jobs.count }, +1 do
      post merge_admin_account_merger_path, params: { older_id: older.id, newer_id: newer.id }
    end

    assert_redirected_to admin_account_merger_path
    assert_empty Clickhouse::Heartbeat.for_user(older)
    assert_equal heartbeat.id, Clickhouse::Heartbeat.for_user(newer).sole.id
    assert_equal older.id, ApiKey.find(api_key.id).user_id
    assert_nil User.find_by(id: newer.id)
    assert_equal 0, Doorkeeper::AccessToken.where(resource_owner_id: newer.id).count
    assert_equal 0, Doorkeeper::AccessGrant.where(resource_owner_id: newer.id).count
    assert_includes flash[:notice], "3 sessions/tokens revoked"
    assert_includes flash[:notice], "related records cleaned up"
    assert_includes flash[:notice], "heartbeat transfer queued"
    job = jobs.order(:created_at).last
    arguments = job.serialized_params.fetch("arguments").first
    assert_equal({ "older_user_id" => older.id, "newer_user_id" => newer.id }, arguments.except("_aj_ruby2_keywords"))
    assert_equal "latency_5m", job.queue_name
    assert_equal "heartbeat_serving_rebuild", job.concurrency_key
  end

  test "merge renames transferred api keys when the older account already has the same key name" do
    admin = User.create!(timezone: "UTC", admin_level: :ultraadmin)
    older = User.create!(timezone: "UTC", username: "older_user")
    newer = User.create!(timezone: "UTC", username: "newer_user")
    sign_in_as(admin)

    older.update_column(:created_at, 2.days.ago)
    newer.update_column(:created_at, 1.day.ago)

    older.api_keys.create!(name: "Wakatime API Key")
    transferred_key = newer.api_keys.create!(name: "Wakatime API Key")

    post merge_admin_account_merger_path, params: { older_id: older.id, newer_id: newer.id }

    assert_redirected_to admin_account_merger_path
    assert_nil User.find_by(id: newer.id)
    assert_equal older.id, transferred_key.reload.user_id
    assert_equal "Wakatime API Key (transferred)", transferred_key.name
    assert_equal [ "Wakatime API Key", "Wakatime API Key (transferred)" ], older.api_keys.order(:name).pluck(:name)
  end

  test "merge transfers instance import sources to the older account when it does not have one" do
    admin = User.create!(timezone: "UTC", admin_level: :ultraadmin)
    older = User.create!(timezone: "UTC", username: "older_user")
    newer = User.create!(timezone: "UTC", username: "newer_user")
    sign_in_as(admin)

    older.update_column(:created_at, 2.days.ago)
    newer.update_column(:created_at, 1.day.ago)

    create_instance_import_source_for(newer, endpoint_url: "https://newer.example.com")

    post merge_admin_account_merger_path, params: { older_id: older.id, newer_id: newer.id }

    assert_redirected_to admin_account_merger_path
    assert_nil User.find_by(id: newer.id)
    assert_equal 1, instance_import_source_count_for(older)
    assert_equal 0, instance_import_source_count_for(newer)
    assert_equal "https://newer.example.com", instance_import_source_endpoint_for(older)
  end

  test "merge removes the newer instance import source when the older account already has one" do
    admin = User.create!(timezone: "UTC", admin_level: :ultraadmin)
    older = User.create!(timezone: "UTC", username: "older_user")
    newer = User.create!(timezone: "UTC", username: "newer_user")
    sign_in_as(admin)

    older.update_column(:created_at, 2.days.ago)
    newer.update_column(:created_at, 1.day.ago)

    create_instance_import_source_for(older, endpoint_url: "https://older.example.com")
    create_instance_import_source_for(newer, endpoint_url: "https://newer.example.com")

    post merge_admin_account_merger_path, params: { older_id: older.id, newer_id: newer.id }

    assert_redirected_to admin_account_merger_path
    assert_nil User.find_by(id: newer.id)
    assert_equal 1, instance_import_source_count_for(older)
    assert_equal 0, instance_import_source_count_for(newer)
    assert_equal "https://older.example.com", instance_import_source_endpoint_for(older)
  end

  test "enqueue failure rolls back the user deletion and transferred records" do
    admin = User.create!(timezone: "UTC", admin_level: :ultraadmin)
    older = User.create!(timezone: "UTC", username: "older_user")
    newer = User.create!(timezone: "UTC", username: "newer_user")
    api_key = newer.api_keys.create!(name: "Rollback Test Key")
    goal = newer.goals.create!(period: "day", target_seconds: 30.minutes.to_i)
    sign_in_as(admin)
    ActiveJob::Base.queue_adapter = RejectingQueueAdapter.new

    post merge_admin_account_merger_path, params: { older_id: older.id, newer_id: newer.id }

    assert_redirected_to admin_account_merger_path
    assert User.exists?(newer.id)
    assert_equal newer.id, api_key.reload.user_id
    assert_equal newer.id, goal.reload.user_id
    assert_equal "Account merge failed.", flash[:alert]
  ensure
    ActiveJob::Base.queue_adapter = :test
  end

  private

  def create_instance_import_source_for(user, endpoint_url:)
    InstanceImportSource.create!(
      user: user,
      endpoint_url: endpoint_url,
      encrypted_api_key: "encrypted-api-key"
    )
  end

  def instance_import_source_count_for(user)
    InstanceImportSource.where(user_id: user.id).count
  end

  def instance_import_source_endpoint_for(user)
    InstanceImportSource.find_by(user_id: user.id)&.endpoint_url
  end
end
