require "test_helper"

class AdminApiKeyExpiryNoticeJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  test "emails each admin once about all of their expiring keys" do
    admin = create(:user, :admin, timezone: "America/New_York")
    create(:email_address, user: admin, email: "admin@example.com")
    expires_at = Time.utc(2026, 12, 26, 3, 30)
    first = create(:admin_api_key, user: admin, name: "Fraud tool", expires_at:)
    second = create(:admin_api_key, user: admin, name: "Script", expires_at:)
    scoped = create(:admin_api_key, user: admin, name: "New scoped key")
    revoked = create(:admin_api_key, user: admin, name: "Old", expires_at:).tap(&:revoke!)

    demoted = create(:user, :admin)
    create(:email_address, user: demoted)
    create(:admin_api_key, user: demoted, expires_at:)
    demoted.update!(admin_level: :default)

    assert_emails 1 do
      AdminApiKeyExpiryNoticeJob.perform_now
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "admin@example.com" ], mail.to
    assert_equal "Your Hackatime admin API keys will be revoked on 25 December 2026", mail.subject
    body = mail.text_part.body.decoded
    assert_includes body, "Fraud tool (#{first.token_preview}...) on 25 December 2026 at 22:30 EST"
    assert_includes body, "Script (#{second.token_preview}...)"
    assert_not_includes body, scoped.name
    assert_not_includes body, revoked.name
    assert_includes body, "http://example.com/admin/admin_api_keys/new"

    assert_no_emails do
      AdminApiKeyExpiryNoticeJob.perform_now
    end
  end
end
