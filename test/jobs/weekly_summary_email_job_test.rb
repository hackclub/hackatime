require "test_helper"

class WeeklySummaryEmailJobTest < ActiveJob::TestCase
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
