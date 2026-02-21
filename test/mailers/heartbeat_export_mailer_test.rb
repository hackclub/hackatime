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

  test "export_ready builds recipient, body, and json attachment" do
    Tempfile.create([ "heartbeat_export_mailer", ".json" ]) do |file|
      file.write({ sample: true }.to_json)
      file.rewind

      mail = HeartbeatExportMailer.export_ready(
        @user,
        recipient_email: @recipient_email,
        file_path: file.path,
        filename: "heartbeats_test.json"
      )

      assert_equal [ @recipient_email ], mail.to
      assert_equal "Your Hackatime heartbeat export is ready", mail.subject
      assert_equal 1, mail.attachments.size

      attachment = mail.attachments.first
      assert_equal "heartbeats_test.json", attachment.filename
      assert_equal "application/json", attachment.mime_type
      assert_equal({ "sample" => true }, JSON.parse(attachment.body.decoded))

      assert_includes mail.html_part.body.decoded, "Your heartbeat export is ready"
      assert_includes mail.text_part.body.decoded, "Your Hackatime heartbeat export has been generated"
      assert_includes mail.text_part.body.decoded, @user.display_name
    end
  end
end
