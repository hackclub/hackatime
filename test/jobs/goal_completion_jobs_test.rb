require "test_helper"
require "webmock/minitest"

class GoalCompletionJobsTest < ActiveJob::TestCase
  setup do
    @original_timeout = Heartbeat.heartbeat_timeout_duration
    Heartbeat.heartbeat_timeout_duration(1.second)
    @user = User.create!(timezone: "America/New_York", slack_uid: "U_GOAL_COMPLETION")
    @user.email_addresses.create!(email: "goals@example.com", source: :signing_in)
    ActionMailer::Base.deliveries.clear
    GoodJob::Job.delete_all
  end

  teardown do
    Heartbeat.heartbeat_timeout_duration(@original_timeout)
    ActionMailer::Base.deliveries.clear
    GoodJob::Job.delete_all
  end

  test "completion check creates one notification per goal period and enqueues selected channels" do
    goal = @user.goals.create!(
      period: "day",
      target_seconds: 1,
      languages: [ "Ruby" ],
      projects: [ "hackatime" ],
      notify_by_email: true,
      notify_by_slack: true
    )

    travel_to Time.utc(2026, 8, 20, 16, 0, 0) do
      create_heartbeat_pair
      GoodJob::Job.delete_all

      assert_difference -> { GoalCompletionNotification.count }, 1 do
        assert_difference -> { GoodJob::Job.where(job_class: "GoalCompletionEmailJob").count }, 1 do
          assert_difference -> { GoodJob::Job.where(job_class: "GoalCompletionSlackJob").count }, 1 do
            GoalCompletionCheckJob.perform_now(@user.id)
          end
        end
      end

      notification = goal.completion_notifications.sole
      assert_equal "day", notification.period
      assert_equal Time.zone.parse("2026-08-20 04:00:00 UTC"), notification.period_started_at
      assert_equal 1, notification.target_seconds
      assert_equal [ "Ruby" ], notification.languages
      assert_equal [ "hackatime" ], notification.projects

      assert_no_difference -> { GoalCompletionNotification.count } do
        GoalCompletionCheckJob.perform_now(@user.id)
      end
    end
  end

  test "completion check does nothing before the target is reached" do
    @user.goals.create!(period: "day", target_seconds: 2, notify_by_email: true)

    travel_to Time.utc(2026, 8, 20, 16, 0, 0) do
      create_heartbeat_pair

      assert_no_difference -> { GoalCompletionNotification.count } do
        GoalCompletionCheckJob.perform_now(@user.id)
      end
    end
  end

  test "completion check creates another notification in the next period" do
    goal = @user.goals.create!(period: "day", target_seconds: 1, notify_by_email: true)

    travel_to Time.utc(2026, 8, 20, 16, 0, 0) do
      create_heartbeat_pair(Time.zone.parse("2026-08-20 09:00:00 -0400"))
      GoalCompletionCheckJob.perform_now(@user.id)
    end

    travel_to Time.utc(2026, 8, 21, 16, 0, 0) do
      create_heartbeat_pair(Time.zone.parse("2026-08-21 09:00:00 -0400"))

      assert_difference -> { goal.completion_notifications.count }, 1 do
        GoalCompletionCheckJob.perform_now(@user.id)
      end
    end

    assert_equal 2, goal.completion_notifications.count
  end

  test "email delivery records success and is idempotent" do
    notification = create_notification

    assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
      GoalCompletionEmailJob.perform_now(notification.id)
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "goals@example.com" ], mail.to
    assert_equal "You reached your day Hackatime goal!", mail.subject
    assert_includes mail.text_part.body.decoded, "Languages: Ruby"
    assert_includes mail.text_part.body.decoded, "Projects: hackatime"
    assert notification.reload.email_delivered_at.present?

    assert_no_difference -> { ActionMailer::Base.deliveries.count } do
      GoalCompletionEmailJob.perform_now(notification.id)
    end
  end

  test "Slack delivery sends a direct message and records success" do
    notification = create_notification
    slack_request = stub_request(:post, "https://slack.com/api/chat.postMessage")
      .with do |request|
        body = JSON.parse(request.body)
        body.fetch("channel") == @user.slack_uid &&
          body.fetch("text").include?("reached your day coding goal") &&
          body.fetch("text").include?("Ruby coding in hackatime")
      end
      .to_return(status: 200, body: { ok: true }.to_json)

    GoalCompletionSlackJob.perform_now(notification.id)

    assert_requested slack_request, times: 1
    assert notification.reload.slack_delivered_at.present?

    GoalCompletionSlackJob.perform_now(notification.id)
    assert_requested slack_request, times: 1
  end

  private

  def create_heartbeat_pair(start_at = Time.zone.parse("2026-08-20 09:00:00 -0400"))
    [ start_at, start_at + 1.second ].each do |time|
      @user.heartbeats.create!(
        time: time.to_i,
        language: "Ruby",
        project: "hackatime",
        category: "coding",
        source_type: :test_entry
      )
    end
  end

  def create_notification
    goal = @user.goals.create!(
      period: "day",
      target_seconds: 1.hour.to_i,
      languages: [ "Ruby" ],
      projects: [ "hackatime" ],
      notify_by_email: true,
      notify_by_slack: true
    )
    goal.completion_notifications.create!(
      period: "day",
      period_started_at: Time.utc(2026, 8, 20),
      target_seconds: 1.hour.to_i,
      tracked_seconds: 75.minutes.to_i,
      languages: [ "Ruby" ],
      projects: [ "hackatime" ]
    )
  end
end
