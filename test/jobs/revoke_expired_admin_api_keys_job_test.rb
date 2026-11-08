require "test_helper"

class RevokeExpiredAdminApiKeysJobTest < ActiveJob::TestCase
  test "revokes keys past their expiry and leaves the rest alone" do
    expired = create(:admin_api_key, name: "Legacy", expires_at: 1.minute.ago)
    expiring = create(:admin_api_key, expires_at: 1.day.from_now)
    permanent = create(:admin_api_key)

    RevokeExpiredAdminApiKeysJob.perform_now

    assert_not_nil expired.reload.revoked_at
    assert_not_equal "Legacy", expired.name
    assert_nil expiring.reload.revoked_at
    assert_nil permanent.reload.revoked_at
  end
end
