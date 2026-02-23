require "test_helper"

class WeeklySummaryMailerTest < ActionMailer::TestCase
  setup do
    @user = User.create!(
      timezone: "UTC",
      weekly_summary_email_enabled: true
    )
    @recipient_email = "weekly-mailer-#{SecureRandom.hex(4)}@example.com"
    @user.email_addresses.create!(email: @recipient_email, source: :signing_in)
  end

  test "weekly_summary renders coding recap and top lists" do
    create_coding_heartbeat(Time.utc(2026, 2, 24, 10, 0, 0), "hackatime-web", "Ruby")
    create_coding_heartbeat(Time.utc(2026, 2, 25, 11, 0, 0), "hackatime-web", "Ruby")
    create_coding_heartbeat(Time.utc(2026, 2, 26, 11, 30, 0), "ops-tools", "JavaScript")

    starts_at = Time.utc(2026, 2, 20, 17, 30, 0)
    ends_at = Time.utc(2026, 2, 27, 17, 30, 0)

    mail = WeeklySummaryMailer.weekly_summary(
      @user,
      recipient_email: @recipient_email,
      starts_at: starts_at,
      ends_at: ends_at
    )

    assert_equal [ @recipient_email ], mail.to
    assert_equal "Your Hackatime weekly summary (Feb 20 - Feb 27, 2026)", mail.subject
    assert_includes mail.html_part.body.decoded, "Your coding recap"
    assert_includes mail.html_part.body.decoded, "Top projects"
    assert_includes mail.text_part.body.decoded, "Feb 20 - Feb 27, 2026"
    assert_includes mail.text_part.body.decoded, "Top languages:"
    assert_includes mail.text_part.body.decoded, "hackatime-web"
    assert_not_includes mail.html_part.body.decoded.downcase, "gradient"
  end

  private

  def create_coding_heartbeat(time, project, language)
    @user.heartbeats.create!(
      entity: "src/#{project}.rb",
      type: "file",
      category: "coding",
      time: time.to_f,
      project: project,
      language: language,
      source_type: :test_entry
    )
  end
end
