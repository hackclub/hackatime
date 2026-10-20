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

  private

  def auth_headers(key)
    { "Authorization" => ActionController::HttpAuthentication::Token.encode_credentials(key.token) }
  end
end
