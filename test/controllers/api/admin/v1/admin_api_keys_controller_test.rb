require "test_helper"

class Api::Admin::V1::AdminApiKeysControllerTest < ActionDispatch::IntegrationTest
  test "records authenticated usage asynchronously and samples busy keys once per minute" do
    key = create(:admin_api_key, user: create(:user, :admin), name: "Busy key")
    headers = auth_headers(key)
    jobs = GoodJob::Job.where(job_class: "RecordAdminApiKeyUsageJob")

    travel_to Time.utc(2026, 10, 20, 15, 23, 17) do
      first_use = Time.current
      assert_difference -> { jobs.count }, 1 do
        25.times do
          get "/api/admin/v1/check", headers: headers
          assert_response :success
        end
      end
      assert_nil key.reload.last_used_at

      travel 30.seconds
      ActiveJob::Base.execute(jobs.order(:created_at).last.serialized_params)
      assert_equal first_use, key.reload.last_used_at

      travel 29.seconds
      assert_no_difference -> { jobs.count } do
        get "/api/admin/v1/check", headers: headers
        assert_response :success
      end

      travel 1.second
      next_use = Time.current
      assert_difference -> { jobs.count }, 1 do
        get "/api/admin/v1/check", headers: headers
        assert_response :success
      end
      ActiveJob::Base.execute(jobs.order(:created_at).last.serialized_params)
      assert_equal next_use, key.reload.last_used_at
    end
  end

  test "rejected credentials do not record usage" do
    revoked = create(:admin_api_key, user: create(:user, :admin), name: "Revoked")
    revoked.revoke!
    demoted = create(:admin_api_key, user: create(:user, :admin), name: "Demoted")
    demoted.user.update!(admin_level: :default)

    assert_no_difference -> { GoodJob::Job.where(job_class: "RecordAdminApiKeyUsageJob").count } do
      [ revoked, demoted ].each do |key|
        get "/api/admin/v1/check", headers: auth_headers(key)
        assert_response :unauthorized
        assert_nil key.reload.last_used_at
        assert_nil key.usage_tracking_enqueued_at
      end
      get "/api/admin/v1/check", headers: { "Authorization" => "Bearer invalid" }
      assert_response :unauthorized
    end
  end

  test "ultraadmin can revoke another user's admin API key" do
    ultraadmin = create(:user, :ultraadmin)
    authentication_key = create(:admin_api_key, user: ultraadmin, name: "Authentication key")
    owner = create(:user, :admin)
    key = create(:admin_api_key, user: owner, name: "Other user's key")

    delete "/api/admin/v1/admin_api_keys/#{key.id}", headers: auth_headers(authentication_key)

    assert_response :success
    assert_not key.reload.active?
  end

  test "superadmin cannot revoke another user's admin API key" do
    superadmin = create(:user, :superadmin)
    authentication_key = create(:admin_api_key, user: superadmin, name: "Authentication key")
    owner = create(:user, :admin)
    key = create(:admin_api_key, user: owner, name: "Other user's key")

    delete "/api/admin/v1/admin_api_keys/#{key.id}", headers: auth_headers(authentication_key)

    assert_response :forbidden
    assert_predicate key.reload, :active?
  end

  test "keys can only call endpoints their scopes allow" do
    admin = create(:user, :superadmin)
    target = create(:user)
    key = create(:admin_api_key, user: admin, scopes: %w[users:read])

    get "/api/admin/v1/user/info", params: { id: target.id }, headers: auth_headers(key)
    assert_response :success

    get "/api/admin/v1/user/heartbeats", params: { id: target.id }, headers: auth_headers(key)
    assert_response :forbidden
    assert_equal "This admin API key is missing the heartbeats:read scope", response.parsed_body["error"]

    post "/api/admin/v1/user/convict", params: { id: target.id, trust_level: "red", reason: "x" }, headers: auth_headers(key)
    assert_response :forbidden
    assert_predicate target.reload, :blue?

    get "/api/admin/v1/check", headers: auth_headers(key)
    assert_response :success

    bans_key = create(:admin_api_key, user: admin, scopes: %w[bans:read])
    get "/api/v1/users/lookup_slack_uid/U123", headers: { "Authorization" => "Bearer #{bans_key.token}" }
    assert_response :forbidden
    assert_equal "This admin API key is missing the users:read scope", response.parsed_body["error"]
  end

  test "every admin API action declares the scope a key needs" do
    routes = Rails.application.routes.routes.filter_map do |route|
      next unless route.path.spec.to_s.start_with?("/api/admin/v1/")
      [ route.defaults[:controller], route.defaults[:action] ]
    end.uniq
    assert_operator routes.size, :>, 30

    unscoped = routes.reject do |controller, action|
      next true if [ controller, action ] == %w[api/admin/v1/admin check]
      scope = "#{controller}_controller".camelize.constantize.admin_api_key_scope_for(action)
      scope.in?(AdminApiKey::SCOPES.keys)
    end
    assert_empty unscoped
  end

  test "keys can't create keys with scopes they lack" do
    admin = create(:user, :admin)
    key = create(:admin_api_key, user: admin, scopes: %w[admin_api_keys:write users:read])

    assert_no_difference -> { AdminApiKey.count } do
      post "/api/admin/v1/admin_api_keys", params: { name: "Escalated", scopes: %w[users:read users:write] }, headers: auth_headers(key), as: :json
    end
    assert_response :forbidden

    post "/api/admin/v1/admin_api_keys", params: { name: "Narrower", scopes: %w[users:read] }, headers: auth_headers(key), as: :json
    assert_response :created
    assert_equal %w[users:read], response.parsed_body.dig("admin_api_key", "scopes")
    assert_equal %w[users:read], admin.admin_api_keys.find_by!(name: "Narrower").scopes
  end

  test "expired keys stop authenticating" do
    key = create(:admin_api_key, user: create(:user, :admin), expires_at: 1.day.from_now)

    get "/api/admin/v1/check", headers: auth_headers(key)
    assert_response :success

    travel 1.day + 1.second do
      get "/api/admin/v1/check", headers: auth_headers(key)
      assert_response :unauthorized
    end
  end

  private

  def auth_headers(key)
    { "Authorization" => ActionController::HttpAuthentication::Token.encode_credentials(key.token) }
  end
end
