require "test_helper"

class AdminApiKeyTest < ActiveSupport::TestCase
  test "requests that loaded the same stale key only schedule one usage update" do
    key = create(:admin_api_key, user: create(:user, :admin), name: "Concurrent key")
    stale_key = AdminApiKey.find(key.id)
    jobs = GoodJob::Job.where(job_class: "RecordAdminApiKeyUsageJob")

    assert_difference -> { jobs.count }, 1 do
      key.record_usage
      stale_key.record_usage
    end
    assert_nil key.reload.last_used_at

    ActiveJob::Base.execute(jobs.order(:created_at).last.serialized_params)
    assert_not_nil key.reload.last_used_at
  end

  test "delayed and repeated usage jobs never move last used backwards" do
    key = create(:admin_api_key, user: create(:user, :admin), name: "Delayed key")
    earlier = Time.utc(2026, 10, 20, 14, 12, 5)
    later = earlier + 3.minutes

    RecordAdminApiKeyUsageJob.perform_now(key.id, later)
    RecordAdminApiKeyUsageJob.perform_now(key.id, earlier)
    RecordAdminApiKeyUsageJob.perform_now(key.id, later)

    assert_equal later, key.reload.last_used_at
  end

  test "records who revoked a key without storing the token" do
    admin = create(:user, :admin)
    revoker = create(:user, :admin)
    key = create(:admin_api_key, user: admin, name: "Audited")
    raw_token = key.token

    PaperTrail.request(whodunnit: revoker.id.to_s) { AdminApiKey.find(key.id).revoke! }

    versions = PaperTrail::Version.where(item_type: "AdminApiKey", item_id: key.id).order(:id)
    assert_equal %w[create update], versions.map(&:event)
    revocation = versions.last
    assert_equal revoker.id.to_s, revocation.whodunnit
    assert_nil YAML.unsafe_load(revocation.object_changes)["revoked_at"].first
    versions.each do |version|
      [ version.object, version.object_changes ].compact.each do |stored|
        assert_not_includes stored, raw_token
        assert_not_includes stored, key.token_bidx
      end
    end
  end

  test "usage tracking does not create versions" do
    key = create(:admin_api_key, user: create(:user, :admin), name: "Busy key")

    assert_no_difference -> { PaperTrail::Version.where(item_type: "AdminApiKey", item_id: key.id).count } do
      key.record_usage
      RecordAdminApiKeyUsageJob.perform_now(key.id, Time.current)
    end
  end

  test "stores a fixed-length preview of the token" do
    admin = create(:user, :admin)
    key = create(:admin_api_key, user: admin, name: "CLI")
    raw_token = key.token

    assert_equal 13, AdminApiKey::TOKEN_PREVIEW_LENGTH
    assert_equal raw_token.first(13), key.reload.token_preview
  end
end
