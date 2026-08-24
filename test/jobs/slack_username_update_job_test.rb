require "test_helper"

class SlackUsernameUpdateJobTest < ActiveJob::TestCase
  setup do
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    User.where.not(slack_uid: nil).update_all(slack_synced_at: Time.current)
  end

  teardown do
    ActiveJob::Base.queue_adapter = @original_queue_adapter
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "enqueues profile syncs for never-synced and stale Slack users" do
    never_synced = create(:user, slack_uid: "U_NEVER_SYNCED")
    stale = create(:user, slack_uid: "U_STALE", slack_synced_at: 2.days.ago)
    create(:user, slack_uid: "U_FRESH", slack_synced_at: 1.hour.ago)
    create(:user)

    assert_enqueued_jobs 2, only: SlackProfileSyncJob do
      SlackUsernameUpdateJob.perform_now
    end

    assert_enqueued_with(job: SlackProfileSyncJob, args: [ never_synced.id ])
    assert_enqueued_with(job: SlackProfileSyncJob, args: [ stale.id ])
  end

  test "enqueues more than the old one hundred user limit" do
    now = Time.current
    users = 101.times.map do |index|
      {
        timezone: "UTC",
        slack_uid: "U_BACKLOG_#{index}",
        slack_synced_at: 2.days.ago,
        created_at: now,
        updated_at: now
      }
    end
    User.insert_all!(users)

    assert_enqueued_jobs 101, only: SlackProfileSyncJob do
      SlackUsernameUpdateJob.perform_now
    end
  end
end
