require "test_helper"

class HeartbeatExportMailerTest < ActionMailer::TestCase
  setup do
    @user = User.create!(
      timezone: "UTC",
      slack_uid: "U#{SecureRandom.hex(5)}",
      username: "mexp_#{SecureRandom.hex(4)}"
    )
    @recipient_email = "mailer-export-#{SecureRandom.hex(6)}@example.com"
  end

  test "export_ready builds recipient and includes download link" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new({ sample: true }.to_json),
      filename: "heartbeats_test.zip",
      content_type: "application/zip",
      metadata: { "heartbeat_export" => true }
    )

    mail = HeartbeatExportMailer.export_ready(
      @user,
      recipient_email: @recipient_email,
      blob: blob,
      filename: "heartbeats_test.zip"
    )

    assert_equal [ @recipient_email ], mail.to
    assert_equal "Your Hackatime heartbeat export is ready", mail.subject
    assert_equal 0, mail.attachments.size

    assert_includes mail.html_part.body.decoded, "Your heartbeat export is ready"
    assert_includes mail.text_part.body.decoded, "Your Hackatime heartbeat export has been generated"
    assert_includes mail.text_part.body.decoded, @user.display_name
    assert_includes mail.text_part.body.decoded, "/rails/active_storage/blobs/redirect/"
    assert_includes mail.text_part.body.decoded, "heartbeats_test.zip"

    blob.purge
  end
end
