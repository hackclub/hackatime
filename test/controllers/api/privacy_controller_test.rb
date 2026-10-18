require "test_helper"
require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)

class Api::PrivacyControllerTest < ActionDispatch::IntegrationTest
  setup do
    @signing_key = OpenSSL::PKey::EC.generate("prime256v1")
    @kid = SecureRandom.uuid
    @jwks_url = "https://privacy-#{@kid}.example.test/jwks"
    @previous_jwks_url = ENV["PRIVACY_JWKS_URL"]
    ENV["PRIVACY_JWKS_URL"] = @jwks_url
    @claims = { iss: "hackclub-privacy", aud: "hackatime", iat: Time.now.to_i,
      exp: Time.now.to_i + 300, jti: SecureRandom.uuid, request_id: SecureRandom.uuid,
      action: "delete", dry_run: true, subject: { emails: [], slack_id: nil, identity_id: nil } }
    stub_request(:get, @jwks_url).to_return(
      body: { keys: [ JWT::JWK.new(@signing_key, kid: @kid).export ] }.to_json,
      headers: { "Content-Type" => "application/json" })
  end

  teardown do
    ENV["PRIVACY_JWKS_URL"] = @previous_jwks_url
    @blob.service.delete(@blob.key) if @blob
    FileUtils.rm_f(@import_file) if @import_file
  end

  test "both endpoints return count-only responses and enforce action and replay protection" do
    %w[delete export].each do |action|
      payload = @claims.merge(action: action, jti: SecureRandom.uuid)
      token = signed_token(payload)
      privacy_post(action, token: token)
      assert_response :ok
      assert_equal({ "request_id" => payload[:request_id], "found" => false,
        "dry_run" => true, "deleted" => {}, "retained" => [] }, response.parsed_body)
      privacy_post(action, token: token)
      assert_response :conflict
      assert_equal({ "error" => "replayed" }, response.parsed_body)
      privacy_post(action, token: signed_token(payload.merge(action: action == "delete" ? "export" : "delete", jti: SecureRandom.uuid)))
      assert_response :bad_request
      assert_equal({ "error" => "action_mismatch" }, response.parsed_body)
    end
  end

  test "rejects wrong issuer audience lifetime time and malformed claims" do
    freeze_time
    now = Time.now.to_i
    [ { iss: "someone-else" }, { aud: "Hackatime" }, { aud: [ "hackatime" ] },
      { exp: now + 301 }, { iat: now + 31, exp: now + 300 },
      { iat: now - 400, exp: now - 31 }, { iat: now + 20, exp: now + 10 },
      { dry_run: "false" }, { subject: {} }, { subject: { emails: [ nil ] } },
      { jti: "" }, { request_id: nil }
    ].each do |invalid|
      privacy_post(token: signed_token(@claims.merge(invalid)))
      assert_response :unauthorized
      assert_equal({ "error" => "invalid_token" }, response.parsed_body)
    end
    %i[iat exp jti request_id subject dry_run].each do |required|
      privacy_post(token: signed_token(@claims.except(required)))
      assert_response :unauthorized
    end
    assert_not PrivacyTokenUse.exists?(jti: @claims[:jti])
  end

  test "enforces the signature ES256 algorithm and exact JWT type" do
    [ { typ: "jwt" }, { typ: nil }, { kid: "unknown" } ].each do |header|
      privacy_post(token: signed_token(@claims, header))
      assert_response :unauthorized
    end
    forged = JWT.encode(@claims, OpenSSL::PKey::EC.generate("prime256v1"), "ES256", typ: "JWT", kid: @kid)
    privacy_post(token: forged)
    assert_response :unauthorized
    privacy_post(token: JWT.encode(@claims, "not-a-public-key", "HS256", typ: "JWT", kid: @kid))
    assert_response :unauthorized
    assert_requested :get, @jwks_url, times: 1
  end

  test "accepts clock leeway and consumes export tokens even when dry_run is false" do
    freeze_time
    now = Time.now.to_i
    payload = @claims.merge(iat: now - 320, exp: now - 20, action: "export", dry_run: false)
    token = signed_token(payload)
    privacy_post("export", token: token)
    assert_response :ok
    assert_equal false, response.parsed_body["dry_run"]
    privacy_post("export", token: token)
    assert_response :conflict
    assert_equal({ "error" => "replayed" }, response.parsed_body)
  end

  test "returns a retryable error when the key server is unavailable" do
    stub_request(:get, @jwks_url).to_return(status: 503)
    privacy_post
    assert_response :service_unavailable
    assert_equal({ "error" => "jwks_unavailable" }, response.parsed_body)
    assert_not PrivacyTokenUse.exists?(jti: @claims[:jti])
  end

  test "logs only the verified request ID and outcome including on rejected identifiers" do
    output = StringIO.new
    previous_logger, previous_sql_logger = Rails.logger, ActiveRecord::Base.logger
    Rails.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(output))
    ActiveRecord::Base.logger = Rails.logger
    [ "/api/privacy/delete", "/api/privacy/delete/", "/api/privacy/delete.json" ].each do |path|
      token = signed_token(@claims.merge(jti: SecureRandom.uuid))
      post "#{path}?slack_id=U_DO_NOT_LOG&identity_id=ident!DO_NOT_LOG", params: { email: "do-not-log@example.test" },
        headers: { "Authorization" => "Bearer #{token}" }
      assert_response :ok
      assert_includes output.string, @claims[:request_id]
      assert_includes output.string, "dry_run"
      [ token, "U_DO_NOT_LOG", "ident!DO_NOT_LOG", "do-not-log@example.test" ].each { |value| assert_not_includes output.string, value }
    end
  ensure
    Rails.logger, ActiveRecord::Base.logger = previous_logger, previous_sql_logger
  end

  test "ignores identifiers and dry_run in the request body and query" do
    user = create(:user, :with_email)
    post "/api/privacy/delete?email=#{user.email_addresses.first.email}",
      params: { subject: { emails: [ user.email_addresses.first.email ] }, dry_run: false }.to_json,
      headers: { "Authorization" => "Bearer #{signed_token}", "Content-Type" => "application/json" }
    assert_response :ok
    assert_equal false, response.parsed_body["found"]
    assert User.exists?(user.id)
  end

  test "erases attributable leftovers when only the signed HCA identity remains" do
    identity = "ident!OrphanHistory"
    job = GoodJob::Job.create!(job_class: "ActionMailer::MailDeliveryJob", active_job_id: SecureRandom.uuid,
      serialized_params: { arguments: [ identity ] })
    version = PaperTrail::Version.create!(item_type: "User", item_id: 0, event: "update",
      object: { hca_id: identity }.to_yaml)
    privacy_post(token: signed_token(@claims.merge(subject: { emails: [], identity_id: identity }, dry_run: false)))
    assert_response :ok
    assert_equal true, response.parsed_body["found"]
    assert_equal 1, response.parsed_body.dig("deleted", "good_jobs")
    assert_equal 1, response.parsed_body.dig("deleted", "versions")
    assert_not GoodJob::Job.exists?(job.id)
    assert_not PaperTrail::Version.exists?(version.id)
  end

  test "history erasure matches decoded whole identifiers without erasing overlapping addresses" do
    @claims[:subject] = { emails: [ "ann@example.org" ], slack_id: "U_EXACT", identity_id: "ident!Exact" }
    versions = [ "email: 'ANN@example.org'", '{"email":"\\u0061nn@example.org"}' ].map do |text|
      PaperTrail::Version.create!(item_type: "User", item_id: 0, event: "update", object: text)
    end
    longer = [ "joann@example.org", "ann@example.org.uk", "ann@example.org.other" ] +
      ".!#$%&'*+/=?^_`{|}~-".chars.map { |prefix| "#{prefix}ann@example.org" }
    preserved = longer.map do |email|
      PaperTrail::Version.create!(item_type: "User", item_id: 0, event: "update", object: { email: email }.to_yaml)
    end
    requests = Class.new(ApplicationRecord) { self.table_name = "notable_requests" }
    jobs = Class.new(ApplicationRecord) { self.table_name = "notable_jobs" }
    exact_request = requests.create!(params: { emails: [ "ANN@example.org" ] }.to_json)
    encoded_request = requests.create!(url: "https://example.test/history?email=ann%40example.org")
    other_request = requests.create!(params: { email: "joann@example.org" }.to_json, url: "https://example.test/history?email=o%27ann%40example.org")
    exact_job = jobs.create!(job: { subject: { identity: "ident!Exact" } }.to_yaml)
    other_job = jobs.create!(job: { email: "o'ann@example.org", slack: "U_EXACT_OTHER", identity: "ident!ExactOther" }.to_yaml)

    privacy_post
    assert_response :ok
    preview = response.parsed_body["deleted"]
    assert_equal 2, preview["versions"]
    assert_equal 2, preview["notable_requests"]
    assert_equal 1, preview["notable_jobs"]
    assert versions.all? { |record| PaperTrail::Version.exists?(record.id) }

    privacy_post(token: signed_token(@claims.merge(jti: SecureRandom.uuid, dry_run: false)))
    assert_response :ok
    assert_equal preview, response.parsed_body["deleted"]
    assert versions.none? { |record| PaperTrail::Version.exists?(record.id) }
    assert preserved.all? { |record| PaperTrail::Version.exists?(record.id) }
    assert_not requests.exists?(exact_request.id)
    assert_not requests.exists?(encoded_request.id)
    assert requests.exists?(other_request.id)
    assert_not jobs.exists?(exact_job.id)
    assert jobs.exists?(other_job.id)

    @claims[:subject] = { emails: [ "o'ann@example.org" ] }
    privacy_post(token: signed_token(@claims.merge(jti: SecureRandom.uuid, dry_run: false)))
    assert_response :ok
    assert_not jobs.exists?(other_job.id), "YAML quoting must not hide apostrophes in a complete address"
    assert_not requests.exists?(other_request.id), "URL values must be decoded before exact comparison"
  end

  test "rolls back the actual erasure and gives the same counts on the real run" do
    create_personal_data
    create(:api_key, user: @person)
    create(:sign_in_token, user: @person)
    HeartbeatExclusion.create!(user: @person, kind: :project_deletion, project: "another-project")
    shared_repo = create(:repository)
    orphan_repo = create(:repository)
    create(:project_repo_mapping, user: @person, repository: shared_repo)
    create(:project_repo_mapping, user: @other, repository: shared_repo)
    create(:project_repo_mapping, user: @person, repository: orphan_repo)
    copied_commit = create(:commit, user: @other, repository: shared_repo, github_raw: {
      commit: { author: { email: "PRIVACY@EXAMPLE.TEST", name: "Private Name" }, message: "shared commit",
        verification: { signature: "old signature", payload: "author Private Name <privacy@example.test>" } }
    })
    deletion = DeletionRequest.create!(user: @other, requested_at: Time.current, admin_approved_by: @person)
    exclusion = HeartbeatExclusion.create!(user: @other, kind: :project_deletion, project: "other-project", created_by: @person)
    @other.update_columns(leaderboard_shadowbanned_by_id: @person.id)
    run = create(:heartbeat_import_run, user: @person)
    FileUtils.mkdir_p(HeartbeatImportRunner::TMP_DIR)
    @import_file = HeartbeatImportRunner::TMP_DIR.join("#{run.id}-remote.json").to_s
    File.write(@import_file, "private import")
    original_versions = PaperTrail::Version.count
    privacy_post
    assert_response :ok
    preview = response.parsed_body
    assert_equal true, preview["found"]
    assert_equal true, preview["dry_run"]
    { "users" => 1, "heartbeats" => 2, "email_addresses" => 2, "active_storage_blobs" => 1 }.each do |type, count|
      assert_equal count, preview["deleted"][type]
    end
    assert preview["retained"].any? { |record| record["type"] == "trust_level_audit_logs" && record["count"] == 1 }
    assert User.exists?(@person.id)
    assert_equal 2, Heartbeat.with_deleted.with_excluded.where(user_id: @person.id).count
    assert_equal original_versions, PaperTrail::Version.count
    assert_equal @person.id, @audit.reload.changed_by_id
    assert @blob.service.exist?(@blob.key)
    assert File.exist?(@import_file)
    assert_equal "Private Name", copied_commit.reload.github_raw.dig("commit", "author", "name")

    privacy_post(token: signed_token(@claims.merge(jti: SecureRandom.uuid, dry_run: false)))
    assert_response :ok
    assert_equal preview["deleted"], response.parsed_body["deleted"]
    assert_equal preview["retained"], response.parsed_body["retained"]
    assert_not User.exists?(@person.id)
    assert_empty EmailAddress.where(user_id: @person.id)
    assert_empty Heartbeat.with_deleted.with_excluded.where(user_id: @person.id)
    assert Heartbeat.with_deleted.with_excluded.exists?(@other_heartbeat.id)
    assert_nil @audit.reload.changed_by_id
    assert_nil @audit.reason
    assert_nil @audit.notes
    assert_not @blob.service.exist?(@blob.key)
    assert_not ActiveStorage::Blob.exists?(@blob.id)
    assert_not File.exist?(@import_file)
    assert Repository.exists?(shared_repo.id)
    assert_not Repository.exists?(orphan_repo.id)
    assert_equal({ "commit" => { "message" => "shared commit" } }, copied_commit.reload.github_raw)
    assert_nil deletion.reload.admin_approved_by_id
    assert_nil exclusion.reload.created_by_id
    assert_nil @other.reload.leaderboard_shadowbanned_by_id

    privacy_post(token: signed_token(@claims.merge(jti: SecureRandom.uuid)))
    assert_equal false, response.parsed_body["found"]
  end

  test "exports counts without changing rows or files even when dry_run is false" do
    create_personal_data
    before = [ @person.reload.attributes, @audit.reload.attributes, PaperTrail::Version.count ]
    privacy_post("export", token: signed_token(@claims.merge(action: "export", dry_run: false)))
    assert_response :ok
    assert_equal true, response.parsed_body["found"]
    assert_equal false, response.parsed_body["dry_run"]
    assert_empty response.parsed_body["deleted"]
    assert response.parsed_body["retained"].any? { |record| record["type"] == "heartbeats" && record["count"] == 2 }
    assert_equal before, [ @person.reload.attributes, @audit.reload.attributes, PaperTrail::Version.count ]
    assert @blob.service.exist?(@blob.key)
  end

  test "matches Slack and HCA independently without treating nil IDs as a match" do
    create_personal_data
    [ { emails: [], slack_id: @person.slack_uid }, { emails: [], identity_id: @person.hca_id } ].each do |subject|
      privacy_post("export", token: signed_token(@claims.merge(action: "export", jti: SecureRandom.uuid, subject: subject)))
      assert_response :ok
      assert response.parsed_body["retained"].any? { |record| record["type"] == "users" && record["count"] == 1 }
    end
  end

  test "refuses shared integration credentials without deleting any data" do
    create_personal_data
    application = create(:oauth_application, owner: @person)
    privacy_post(token: signed_token(@claims.merge(dry_run: false)))
    assert_response :conflict
    assert_equal({ "error" => "manual_review_required" }, response.parsed_body)
    assert User.exists?(@person.id)
    assert OauthApplication.exists?(application.id)
    assert @blob.service.exist?(@blob.key)
  end

  test "rolls database deletion back when storage fails and permits a fresh-token retry" do
    create_personal_data
    # A directory where the object should be forces a real DiskService deletion
    # failure, without mocking the database or deletion implementation.
    path = @blob.service.path_for(@blob.key)
    File.delete(path)
    Dir.mkdir(path)
    begin
      privacy_post(token: signed_token(@claims.merge(dry_run: false)))
    ensure
      Dir.rmdir(path)
    end
    assert_response :service_unavailable
    assert_equal({ "error" => "storage_unavailable" }, response.parsed_body)
    assert User.exists?(@person.id)
    assert_equal 2, Heartbeat.with_deleted.with_excluded.where(user_id: @person.id).count
    assert_equal @person.id, @audit.reload.changed_by_id
    assert ActiveStorage::Blob.exists?(@blob.id)
    privacy_post(token: signed_token(@claims.merge(dry_run: false, jti: SecureRandom.uuid)))
    assert_response :ok
    assert_not User.exists?(@person.id)
  end

  test "deletes pending jobs and orphan executions without matching another numeric user ID" do
    create_personal_data
    personal = GoodJob::Job.create!(job_class: "HeartbeatExportJob", active_job_id: SecureRandom.uuid,
      serialized_params: { arguments: [ @person.id ] })
    unrelated = GoodJob::Job.create!(job_class: "HeartbeatExportJob", active_job_id: SecureRandom.uuid,
      serialized_params: { arguments: [ "#{@person.id}0".to_i ] })
    execution = GoodJob::Execution.create!(active_job_id: SecureRandom.uuid, job_class: "HeartbeatExportJob",
      serialized_params: { arguments: [ @person.id ] })
    privacy_post(token: signed_token(@claims.merge(dry_run: false)))
    assert_response :ok
    assert_not GoodJob::Job.exists?(personal.id)
    assert_not GoodJob::Execution.exists?(execution.id)
    assert GoodJob::Job.exists?(unrelated.id)
  end

  test "retries instead of deleting an account while its job is running" do
    create_personal_data
    { "HeartbeatExportJob" => [ @person.id ], "ScanGithubReposJob" => [] }.each do |job_class, arguments|
      job = GoodJob::Job.create!(job_class: job_class, active_job_id: SecureRandom.uuid,
        performed_at: Time.current, serialized_params: { arguments: arguments })
      privacy_post(token: signed_token(@claims.merge(jti: SecureRandom.uuid, dry_run: false)))
      assert_response :service_unavailable
      assert_equal({ "error" => "work_in_progress" }, response.parsed_body)
      assert User.exists?(@person.id)
      assert GoodJob::Job.exists?(job.id)
      job.delete
    end
  end

  private

  def signed_token(payload = @claims, header = {})
    JWT.encode(payload, @signing_key, "ES256", { typ: "JWT", kid: @kid }.merge(header))
  end

  def privacy_post(action = "delete", token: signed_token)
    post "/api/privacy/#{action}", headers: { "Authorization" => "Bearer #{token}" }
  end

  def create_personal_data
    @person = create(:user, :with_email, :with_slack, hca_id: "ident!Privacy", email: "privacy@example.test")
    @other = create(:user, :with_email)
    @claims[:subject] = { emails: [ "SECONDARY@EXAMPLE.TEST" ], slack_id: nil, identity_id: nil }
    create(:email_address, user: @person, email: "secondary@example.test")
    create(:heartbeat, user: @person, project: "private-project", deleted_at: Time.current)
    create(:heartbeat, user: @person, project: "another-project", time: 1.minute.ago.to_f)
    @other_heartbeat = create(:heartbeat, user: @other)
    @audit = create(:trust_level_audit_log, user: @other, changed_by: @person, reason: "Identifying text", notes: "Private author notes")
    @blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("private export"), filename: "private.zip",
      metadata: { heartbeat_export: true, user_id: @person.id })
  end
end
