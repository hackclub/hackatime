require "test_helper"

class GoalMailerTest < ActionMailer::TestCase
  setup do
    @user = User.create!(timezone: "UTC")
    @goal = @user.goals.create!(period: "day", target_seconds: 7200, notify_email: true)
  end

  test "goal_about_to_miss renders remaining time and unsubscribe link" do
    mail = GoalMailer.goal_about_to_miss(
      @user,
      @goal,
      recipient_email: "goal-mailer@example.com",
      tracked_seconds: 3600,
      remaining_seconds: 4.hours.to_i
    )

    assert_equal [ "goal-mailer@example.com" ], mail.to
    assert_equal "You're about to miss your daily coding goal!", mail.subject
    assert_includes mail.html_part.body.decoded, "Heads up!"
    assert_includes mail.html_part.body.decoded, "Unsubscribe"
    assert_includes mail.text_part.body.decoded, "Heads up!"
    assert_includes mail.text_part.body.decoded, "4h"
    assert_includes mail.header["List-Unsubscribe"].to_s, "/mailkick/subscriptions/"
  end

  test "goal_about_to_miss includes goal scope in the subject" do
    scoped_goal = @user.goals.create!(
      period: "day",
      target_seconds: 7200,
      notify_email: true,
      languages: [ "Rust" ],
      projects: [ "hackatime" ]
    )

    mail = GoalMailer.goal_about_to_miss(
      @user,
      scoped_goal,
      recipient_email: "goal-mailer@example.com",
      tracked_seconds: 3600,
      remaining_seconds: 4.hours.to_i
    )

    assert_equal "You're about to miss your daily Rust coding goal for hackatime!", mail.subject
  end
end
