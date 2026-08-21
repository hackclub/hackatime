class GoalMailer < ApplicationMailer
  helper :application

  def goal_about_to_miss(user, goal, recipient_email:, tracked_seconds:, remaining_seconds:)
    @user = user
    @goal = goal
    @tracked_seconds = tracked_seconds
    @remaining_seconds = remaining_seconds
    @unsubscribe_url = mailkick_unsubscribe_url(@user, "goal_notifications")

    mail(
      to: recipient_email,
      subject: "You're about to miss your #{goal.period_adjective} #{goal.scope_description}!"
    )
  end
end
