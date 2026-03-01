require "test_helper"

class WeeklySummaryEmailJobTest < ActiveJob::TestCase
  DISABLED_REASON = "Weekly summary delivery is intentionally disabled. See WeeklySummaryEmailJob for context.".freeze

  setup do
    ActionMailer::Base.deliveries.clear
    Flipper.enable(:weekly_summary_emails)
    GoodJob::Job.delete_all
  end

  teardown do
    Flipper.disable(:weekly_summary_emails)
    GoodJob::Job.delete_all
  end

  test "enqueues for subscribed users who signed up recently or coded recently" do
    reference_time = Time.utc(2026, 3, 1, 12, 0, 0)
    cutoff = reference_time - 3.weeks

    recent_signup = User.create!(timezone: "UTC")
    recent_signup.update_column(:created_at, cutoff + 1.hour)

    recent_coder = User.create!(timezone: "UTC")
    recent_coder.update_column(:created_at, cutoff - 1.day)
    create_coding_heartbeat(recent_coder, cutoff + 2.hours, "recent-coder", "Ruby")

    stale_user = User.create!(timezone: "UTC")
    stale_user.update_column(:created_at, cutoff - 1.day)
    create_coding_heartbeat(stale_user, cutoff - 2.hours, "stale-user", "Ruby")

    unsubscribed_recent_coder = User.create!(timezone: "UTC")
    unsubscribed_recent_coder.unsubscribe("weekly_summary")
    create_coding_heartbeat(unsubscribed_recent_coder, cutoff + 3.hours, "unsubscribed", "Ruby")

    assert_difference -> { GoodJob::Job.where(job_class: "WeeklySummaryUserEmailJob").count }, 2 do
      WeeklySummaryEmailJob.perform_now(reference_time)
    end

    jobs = GoodJob::Job.where(job_class: "WeeklySummaryUserEmailJob").order(:id)
    enqueued_user_ids = jobs.map { |job| job.serialized_params.fetch("arguments").first.to_i }.sort
    enqueued_reference_times = jobs.map { |job| job.serialized_params.fetch("arguments").second }.uniq

    assert_equal [ recent_signup.id, recent_coder.id ].sort, enqueued_user_ids
    assert_equal [ reference_time.iso8601 ], enqueued_reference_times
  end

  test "does not enqueue summaries when feature flag is disabled" do
    Flipper.disable(:weekly_summary_emails)
    User.create!(timezone: "UTC")

    assert_no_difference -> { GoodJob::Job.where(job_class: "WeeklySummaryUserEmailJob").count } do
      WeeklySummaryEmailJob.perform_now(Time.utc(2026, 3, 1, 12, 0, 0))
    end
  end

  test "sends weekly summaries only for opted-in users with email at friday 17:30 utc" do
    skip DISABLED_REASON

    # enabled_user = User.create!(timezone: "UTC", weekly_summary_email_enabled: true)
    # enabled_user.email_addresses.create!(email: "enabled-#{SecureRandom.hex(4)}@example.com", source: :signing_in)
    # create_coding_heartbeat(enabled_user, Time.utc(2026, 2, 21, 12, 0, 0), "project-enabled", "Ruby")
    # create_coding_heartbeat(enabled_user, Time.utc(2026, 2, 21, 12, 20, 0), "project-enabled", "Ruby")

    # disabled_user = User.create!(timezone: "UTC", weekly_summary_email_enabled: false)
    # disabled_user.email_addresses.create!(email: "disabled-#{SecureRandom.hex(4)}@example.com", source: :signing_in)
    # create_coding_heartbeat(disabled_user, Time.utc(2026, 2, 21, 13, 0, 0), "project-disabled", "Ruby")
    # create_coding_heartbeat(disabled_user, Time.utc(2026, 2, 21, 13, 20, 0), "project-disabled", "Ruby")

    # user_without_email = User.create!(timezone: "UTC", weekly_summary_email_enabled: true)
    # create_coding_heartbeat(user_without_email, Time.utc(2026, 2, 20, 14, 0, 0), "project-no-email", "Ruby")

    # reference_time = Time.utc(2026, 2, 27, 17, 30, 0) # Friday, 5:30 PM GMT

    # assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
    #   WeeklySummaryEmailJob.perform_now(reference_time)
    # end

    # mail = ActionMailer::Base.deliveries.last
    # assert_equal [ enabled_user.email_addresses.first.email ], mail.to
    # assert_equal "Your Hackatime weekly summary (Feb 16 - Feb 23, 2026)", mail.subject
    # assert_includes mail.text_part.body.decoded, "Top projects:"
  end

  test "uses previous local calendar week for each user's timezone" do
    skip DISABLED_REASON

    # user = User.create!(timezone: "America/Los_Angeles", weekly_summary_email_enabled: true)
    # user.email_addresses.create!(email: "la-#{SecureRandom.hex(4)}@example.com", source: :signing_in)
    # create_coding_heartbeat(user, Time.utc(2026, 2, 16, 8, 30, 0), "local-week-in-range", "Ruby")
    # create_coding_heartbeat(user, Time.utc(2026, 2, 16, 8, 50, 0), "local-week-in-range", "Ruby")
    # create_coding_heartbeat(user, Time.utc(2026, 2, 16, 7, 30, 0), "local-week-out-of-range", "Ruby")

    # reference_time = Time.utc(2026, 2, 27, 17, 30, 0)

    # assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
    #   WeeklySummaryEmailJob.perform_now(reference_time)
    # end

    # mail = ActionMailer::Base.deliveries.last
    # assert_equal "Your Hackatime weekly summary (Feb 16 - Feb 23, 2026)", mail.subject
    # assert_includes mail.text_part.body.decoded, "Feb 16 - Feb 23, 2026"
    # assert_includes mail.text_part.body.decoded, "local-week-in-range"
    # assert_not_includes mail.text_part.body.decoded, "local-week-out-of-range"
  end

  test "does not send weekly summaries outside friday 17:30 utc" do
    skip DISABLED_REASON

    # user = User.create!(timezone: "UTC", weekly_summary_email_enabled: true)
    # user.email_addresses.create!(email: "outside-window-#{SecureRandom.hex(4)}@example.com", source: :signing_in)
    # create_coding_heartbeat(user, Time.utc(2026, 2, 20, 12, 0, 0), "project-outside", "Ruby")

    # reference_time = Time.utc(2026, 2, 27, 17, 29, 0)

    # assert_no_difference -> { ActionMailer::Base.deliveries.count } do
    #   WeeklySummaryEmailJob.perform_now(reference_time)
    # end
  end

  private

  def create_coding_heartbeat(user, time, project, language)
    user.heartbeats.create!(
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
