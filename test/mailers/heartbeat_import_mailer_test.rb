require "test_helper"

class HeartbeatImportMailerTest < ActionMailer::TestCase
  setup do
    @user = User.create!(
      timezone: "UTC",
      slack_uid: "U#{SecureRandom.hex(5)}",
      username: "mimp_#{SecureRandom.hex(4)}"
    )
    @recipient_email = "mailer-import-#{SecureRandom.hex(6)}@example.com"
  end

  test "wakatime_manual_download_required builds recipient and includes instructions" do
    mail = HeartbeatImportMailer.wakatime_manual_download_required(
      @user,
      recipient_email: @recipient_email
    )

    assert_equal [ @recipient_email ], mail.to
    assert_equal "Your WakaTime import needs an export link", mail.subject
    assert_includes mail.html_part.body.decoded, "Paste export link"
    assert_includes mail.html_part.body.decoded, "https://wakatime.com/settings/account"
    assert_includes mail.text_part.body.decoded, "https://wakatime.s3.amazonaws.com"
    assert_includes mail.text_part.body.decoded, "/my/heartbeat_imports/wakatime_download_link"
  end

  test "import_completed includes the import summary" do
    run = @user.heartbeat_import_runs.create!(
      source_kind: :wakatime_dump,
      state: :completed,
      encrypted_api_key: "secret",
      imported_count: 42,
      total_count: 50,
      skipped_count: 8,
      message: "Imported 42 out of 50 heartbeats in 1.2s. Skipped 8 duplicate heartbeats."
    )

    mail = HeartbeatImportMailer.import_completed(
      @user,
      run:,
      recipient_email: @recipient_email
    )

    assert_equal [ @recipient_email ], mail.to
    assert_equal "Your WakaTime import is complete", mail.subject
    assert_includes mail.html_part.body.decoded, "Your WakaTime import is complete"
    assert_includes mail.text_part.body.decoded, run.message
    assert_includes mail.text_part.body.decoded, "/my/settings/data"
  end

  test "import_failed includes the failure reason" do
    run = @user.heartbeat_import_runs.create!(
      source_kind: :hackatime_v1_dump,
      state: :failed,
      encrypted_api_key: "secret",
      error_message: "Hackatime v1 ran into an error while processing the import. Please reach out to #hackatime-help on Slack."
    )

    mail = HeartbeatImportMailer.import_failed(
      @user,
      run:,
      recipient_email: @recipient_email
    )

    assert_equal [ @recipient_email ], mail.to
    assert_equal "Your Hackatime v1 import failed", mail.subject
    assert_includes mail.html_part.body.decoded, "Your Hackatime v1 import failed"
    assert_includes mail.text_part.body.decoded, run.error_message
    assert_includes mail.text_part.body.decoded, "/my/settings/data"
  end
end
