require "test_helper"
require "webmock/minitest"

class GoalUserNotificationJobTest < ActiveJob::TestCase
  setup do
    ActionMailer::Base.deliveries.clear
    @user = User.create!(timezone: "UTC")
    @user.subscribe("goal_notifications")
  end

  teardown do
    ActionMailer::Base.deliveries.clear
  end

  test "warns the user when most of the period elapsed and goal is incomplete" do
    goal = @user.goals.create!(period: "day", target_seconds: 2.hours.to_i, notify_email: true)
    @user.email_addresses.create!(email: "goal-test@example.com", source: :signing_in)
    # 20:00 UTC is ~83% through the UTC day; one heartbeat pair = 1 tracked second
    create_heartbeat_pair("2026-08-19 09:00:00")

    travel_to Time.utc(2026, 8, 19, 20, 0, 0) do
      GoalUserNotificationJob.perform_now(@user.id, Time.current.utc.iso8601)
    end

    assert_equal 1, ActionMailer::Base.deliveries.size
    delivery = ActionMailer::Base.deliveries.first
    assert_equal [ "goal-test@example.com" ], delivery.to
    assert_includes delivery.subject, "about to miss your daily coding goal"
    assert_equal Time.utc(2026, 8, 19, 0, 0, 0), goal.reload.last_missed_notification_period_start
  end

  test "does not warn before the warning threshold" do
    @user.goals.create!(period: "day", target_seconds: 2.hours.to_i, notify_email: true)
    @user.email_addresses.create!(email: "goal-test@example.com", source: :signing_in)
    create_heartbeat_pair("2026-08-19 09:00:00")

    travel_to Time.utc(2026, 8, 19, 12, 0, 0) do
      GoalUserNotificationJob.perform_now(@user.id, Time.current.utc.iso8601)
    end

    assert_empty ActionMailer::Base.deliveries
  end

  test "does not warn for the same period twice" do
    @user.goals.create!(period: "day", target_seconds: 2.hours.to_i, notify_email: true)
    @user.email_addresses.create!(email: "goal-test@example.com", source: :signing_in)
    create_heartbeat_pair("2026-08-19 09:00:00")

    travel_to Time.utc(2026, 8, 19, 20, 0, 0) do
      GoalUserNotificationJob.perform_now(@user.id, Time.current.utc.iso8601)
      GoalUserNotificationJob.perform_now(@user.id, Time.current.utc.iso8601)
    end

    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test "warns again in a new period" do
    goal = @user.goals.create!(period: "day", target_seconds: 2.hours.to_i, notify_email: true)
    @user.email_addresses.create!(email: "goal-test@example.com", source: :signing_in)

    travel_to Time.utc(2026, 8, 19, 20, 0, 0) do
      create_heartbeat_pair("2026-08-19 09:00:00")
      GoalUserNotificationJob.perform_now(@user.id, Time.current.utc.iso8601)
    end

    travel_to Time.utc(2026, 8, 20, 20, 0, 0) do
      create_heartbeat_pair("2026-08-20 09:00:00")
      GoalUserNotificationJob.perform_now(@user.id, Time.current.utc.iso8601)
    end

    assert_equal 2, ActionMailer::Base.deliveries.size
    assert_equal Time.utc(2026, 8, 20, 0, 0, 0), goal.reload.last_missed_notification_period_start
  end

  test "does not warn when the goal is already met" do
    goal = @user.goals.create!(period: "day", target_seconds: 1, notify_email: true)
    @user.email_addresses.create!(email: "goal-test@example.com", source: :signing_in)
    create_heartbeat_pair("2026-08-19 09:00:00")

    travel_to Time.utc(2026, 8, 19, 23, 0, 0) do
      GoalUserNotificationJob.perform_now(@user.id, Time.current.utc.iso8601)
    end

    assert_empty ActionMailer::Base.deliveries
    assert_nil goal.reload.last_missed_notification_period_start
  end

  test "does not email when user unsubscribed from goal notifications" do
    @user.goals.create!(period: "day", target_seconds: 2.hours.to_i, notify_email: true)
    @user.email_addresses.create!(email: "goal-test@example.com", source: :signing_in)
    @user.unsubscribe("goal_notifications")
    create_heartbeat_pair("2026-08-19 09:00:00")

    travel_to Time.utc(2026, 8, 19, 20, 0, 0) do
      GoalUserNotificationJob.perform_now(@user.id, Time.current.utc.iso8601)
    end

    assert_empty ActionMailer::Base.deliveries
  end

  test "sends a Slack warning when goal is about to be missed" do
    with_slack_bot_token do
      @user.update!(slack_uid: "U_GOAL123")
      @user.goals.create!(period: "day", target_seconds: 2.hours.to_i, notify_slack: true)
      create_heartbeat_pair("2026-08-19 09:00:00")

      stub = stub_request(:post, "https://slack.com/api/chat.postMessage")
        .with { |request| JSON.parse(request.body)["text"].to_s.include?("Heads up!") }
        .to_return(body: { ok: true }.to_json)

      travel_to Time.utc(2026, 8, 19, 20, 0, 0) do
        GoalUserNotificationJob.perform_now(@user.id, Time.current.utc.iso8601)
      end

      assert_requested stub
    end
  end

  test "does not mark the period notified when Slack rejects the message" do
    with_slack_bot_token do
      @user.update!(slack_uid: "U_GOAL123")
      goal = @user.goals.create!(period: "day", target_seconds: 2.hours.to_i, notify_slack: true)
      create_heartbeat_pair("2026-08-19 09:00:00")

      stub_request(:post, "https://slack.com/api/chat.postMessage")
        .to_return(body: { ok: false, error: "not_in_channel" }.to_json)

      travel_to Time.utc(2026, 8, 19, 20, 0, 0) do
        assert_nothing_raised do
          GoalUserNotificationJob.perform_now(@user.id, Time.current.utc.iso8601)
        end
      end

      assert_nil goal.reload.last_missed_notification_period_start
    end
  end

  test "keeps notifying remaining goals when one goal's delivery fails" do
    with_slack_bot_token do
      @user.update!(slack_uid: "U_GOAL123")
      first_goal = @user.goals.create!(period: "day", target_seconds: 2.hours.to_i, notify_slack: true)
      second_goal = @user.goals.create!(period: "day", target_seconds: 3.hours.to_i, notify_slack: true)
      create_heartbeat_pair("2026-08-19 09:00:00")

      # First request fails, every later request succeeds.
      stub_request(:post, "https://slack.com/api/chat.postMessage")
        .to_return(body: { ok: false, error: "not_in_channel" }.to_json)
        .to_return(body: { ok: true }.to_json)

      travel_to Time.utc(2026, 8, 19, 20, 0, 0) do
        GoalUserNotificationJob.perform_now(@user.id, Time.current.utc.iso8601)
      end

      assert_requested :post, "https://slack.com/api/chat.postMessage", times: 2
      assert_nil first_goal.reload.last_missed_notification_period_start
      assert_equal Time.utc(2026, 8, 19, 0, 0, 0), second_goal.reload.last_missed_notification_period_start
    end
  end

  test "an email delivery error does not block the Slack channel or other goals" do
    with_slack_bot_token do
      @user.update!(slack_uid: "U_GOAL123")
      first_goal = @user.goals.create!(period: "day", target_seconds: 2.hours.to_i, notify_slack: true, notify_email: true)
      second_goal = @user.goals.create!(period: "day", target_seconds: 3.hours.to_i, notify_slack: true, notify_email: true)
      @user.email_addresses.create!(email: "goal-test@example.com", source: :signing_in)
      create_heartbeat_pair("2026-08-19 09:00:00")

      failing_mail = Object.new
      def failing_mail.deliver_now = raise Net::SMTPFatalError, "550 mailbox unavailable"

      stub_request(:post, "https://slack.com/api/chat.postMessage")
        .to_return(body: { ok: true }.to_json)

      GoalMailer.define_singleton_method(:goal_about_to_miss) { |*| failing_mail }
      begin
        travel_to Time.utc(2026, 8, 19, 20, 0, 0) do
          GoalUserNotificationJob.perform_now(@user.id, Time.current.utc.iso8601)
        end
      ensure
        GoalMailer.singleton_class.remove_method(:goal_about_to_miss)
      end

      assert_requested :post, "https://slack.com/api/chat.postMessage", times: 2
      assert_equal Time.utc(2026, 8, 19, 0, 0, 0), first_goal.reload.last_missed_notification_period_start
      assert_equal Time.utc(2026, 8, 19, 0, 0, 0), second_goal.reload.last_missed_notification_period_start
    end
  end

  test "sends over both channels when both are enabled" do
    with_slack_bot_token do
      @user.update!(slack_uid: "U_GOAL123")
      @user.goals.create!(period: "day", target_seconds: 2.hours.to_i, notify_slack: true, notify_email: true)
      @user.email_addresses.create!(email: "goal-test@example.com", source: :signing_in)
      create_heartbeat_pair("2026-08-19 09:00:00")

      stub_request(:post, "https://slack.com/api/chat.postMessage")
        .to_return(body: { ok: true }.to_json)

      travel_to Time.utc(2026, 8, 19, 20, 0, 0) do
        GoalUserNotificationJob.perform_now(@user.id, Time.current.utc.iso8601)
      end

      assert_requested :post, "https://slack.com/api/chat.postMessage", times: 1
      assert_equal 1, ActionMailer::Base.deliveries.size
    end
  end

  private

  def with_slack_bot_token(&block)
    ENV["SAILORS_LOG_SLACK_BOT_OAUTH_TOKEN"] = "test-bot-token"
    block.call
  ensure
    ENV.delete("SAILORS_LOG_SLACK_BOT_OAUTH_TOKEN")
  end

  def create_heartbeat_pair(start_time)
    start_at = ActiveSupport::TimeZone["UTC"].parse(start_time)

    Heartbeat.create!(
      user: @user,
      time: start_at.to_i,
      language: "Ruby",
      project: "alpha",
      category: "coding",
      source_type: :test_entry
    )

    Heartbeat.create!(
      user: @user,
      time: (start_at + 1.second).to_i,
      language: "Ruby",
      project: "alpha",
      category: "coding",
      source_type: :test_entry
    )
  end
end
