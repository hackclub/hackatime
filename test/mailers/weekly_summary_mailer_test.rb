require "test_helper"
require "webmock/minitest"

class WeeklySummaryMailerTest < ActionMailer::TestCase
  setup do
    @user = User.create!(timezone: "UTC")
    @recipient_email = "weekly-mailer-#{SecureRandom.hex(4)}@example.com"
    @user.email_addresses.create!(email: @recipient_email, source: :signing_in)
  end

  test "weekly_summary renders coding recap and top lists" do
    stub_stats_server(
      duration: 9000,
      project_groups: { "hackatime-web" => 7200, "ops-tools" => 1800 },
      language_groups: { "Ruby" => 7200, "JavaScript" => 1800 }
    )

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
    assert_includes mail.text_part.body.decoded, "Feb 20 - Feb 27, 2026"
    assert_not_includes mail.html_part.body.decoded.downcase, "gradient"
    assert_includes mail.html_part.body.decoded, "Unsubscribe"
    assert_includes mail.header["List-Unsubscribe"].to_s, "/mailkick/subscriptions/"
  end

  test "weekly_summary uses an exclusive upper bound for stats queries" do
    duration_requests = []
    grouped_requests = []
    stub_stats_server(
      duration: 120,
      project_groups: { "hackatime-web" => 120 },
      language_groups: { "Ruby" => 120 },
      duration_recorder: ->(body) { duration_requests << body },
      grouped_recorder: ->(body) { grouped_requests << body }
    )

    starts_at = Time.utc(2026, 2, 20, 17, 30, 0)
    ends_at = Time.utc(2026, 2, 27, 17, 30, 0)

    create_coding_heartbeat(ends_at - 1.minute, "hackatime-web", "Ruby")
    create_coding_heartbeat(ends_at, "boundary-project", "Rust")

    mail = WeeklySummaryMailer.weekly_summary(
      @user,
      recipient_email: @recipient_email,
      starts_at: starts_at,
      ends_at: ends_at
    )
    mail.message

    expected_end_time = ends_at.to_f - 1e-6

    assert_equal 1, duration_requests.size
    assert_operator duration_requests.first["end_time"], :<, ends_at.to_f
    assert_in_delta expected_end_time, duration_requests.first["end_time"], 1e-6
    assert_equal 2, grouped_requests.size
    assert grouped_requests.all? { |body| body["end_time"] < ends_at.to_f }
    assert grouped_requests.all? { |body| (body["end_time"] - expected_end_time).abs <= 1e-6 }
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

  def stub_stats_server(duration:, project_groups:, language_groups:, duration_recorder: nil, grouped_recorder: nil)
    WebMock.reset!

    stub_request(:post, "#{StatsClient::RUST_URL}/api/v1/duration")
      .to_return do |request|
        duration_recorder&.call(JSON.parse(request.body))
        {
          status: 200,
          body: { total_seconds: duration }.to_json,
          headers: { "Content-Type" => "application/json" }
        }
      end

    stub_request(:post, "#{StatsClient::RUST_URL}/api/v1/duration/grouped")
      .to_return do |request|
        body = JSON.parse(request.body)
        grouped_recorder&.call(body)

        groups = case body["group_by"]
        when "project"
          project_groups
        when "language"
          language_groups
        else
          {}
        end

        {
          status: 200,
          body: { groups: groups }.to_json,
          headers: { "Content-Type" => "application/json" }
        }
      end
  end
end
