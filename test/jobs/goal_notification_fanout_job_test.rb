require "test_helper"

class GoalNotificationFanoutJobTest < ActiveJob::TestCase
  setup do
    GoodJob::Job.delete_all
  end

  teardown do
    GoodJob::Job.delete_all
  end

  test "enqueues per-user jobs for users with notification-enabled goals" do
    notifying_user = User.create!(timezone: "UTC")
    notifying_user.goals.create!(period: "day", target_seconds: 1800, notify_slack: true)
    email_user = User.create!(timezone: "UTC")
    email_user.goals.create!(period: "week", target_seconds: 3600, notify_email: true)

    quiet_user = User.create!(timezone: "UTC")
    quiet_user.goals.create!(period: "day", target_seconds: 1800)

    assert_difference -> { GoodJob::Job.where(job_class: "GoalUserNotificationJob").count }, 2 do
      GoalNotificationFanoutJob.perform_now(Time.utc(2026, 8, 19, 12, 0, 0))
    end

    enqueued_user_ids = GoodJob::Job.where(job_class: "GoalUserNotificationJob")
      .map { |job| job.serialized_params.fetch("arguments").first.to_i }.sort

    assert_equal [ notifying_user.id, email_user.id ].sort, enqueued_user_ids
  end

  test "skips users with pending deletion" do
    user = User.create!(timezone: "UTC")
    user.goals.create!(period: "day", target_seconds: 1800, notify_slack: true)
    DeletionRequest.create_for_user!(user)

    assert_no_difference -> { GoodJob::Job.where(job_class: "GoalUserNotificationJob").count } do
      GoalNotificationFanoutJob.perform_now(Time.utc(2026, 8, 19, 12, 0, 0))
    end
  end

  test "resumes from the last enqueued user after an interruption" do
    user_a = create_notifying_user
    user_b = create_notifying_user
    reference_time = Time.utc(2026, 8, 19, 12, 0, 0)

    adapter = GoalNotificationFanoutJob.queue_adapter
    adapter.define_singleton_method(:stopping?) { true }
    begin
      GoalNotificationFanoutJob.perform_now(reference_time)
    ensure
      adapter.singleton_class.remove_method(:stopping?)
    end

    # The first run enqueued only the first user before checkpointing.
    assert_equal [ user_a.id ], enqueued_goal_user_notification_user_ids

    resumed_job = GoodJob::Job.where(job_class: "GoalNotificationFanoutJob").order(:id).last
    # advance! stores the successor of the last enqueued user id
    assert_equal [ "enqueue_user_notifications", user_a.id + 1 ], resumed_job.serialized_params.dig("continuation", "current")

    GoalNotificationFanoutJob.execute(resumed_job.serialized_params)

    assert_equal [ user_a.id, user_b.id ].sort, enqueued_goal_user_notification_user_ids.sort
  end

  private

  def create_notifying_user
    user = User.create!(timezone: "UTC")
    user.goals.create!(period: "day", target_seconds: 1800, notify_slack: true)
    user
  end

  def enqueued_goal_user_notification_user_ids
    GoodJob::Job.where(job_class: "GoalUserNotificationJob")
      .map { |job| job.serialized_params.fetch("arguments").first.to_i }
  end
end
