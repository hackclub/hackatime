class GoalCompletionMailer < ApplicationMailer
  helper :application

  def reached(notification, recipient_email:)
    @notification = notification
    @user = notification.goal.user
    @target_duration = ApplicationController.helpers.short_time_simple(notification.target_seconds)
    @tracked_duration = ApplicationController.helpers.short_time_simple(notification.tracked_seconds)
    @goals_url = my_settings_goals_url

    mail(
      to: recipient_email,
      subject: "You reached your #{notification.period} Hackatime goal!"
    )
  end
end
