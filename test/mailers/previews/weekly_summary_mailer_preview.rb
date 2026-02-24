class WeeklySummaryMailerPreview < ActionMailer::Preview
  def weekly_summary
    user = User.first || User.new(username: "preview_user", timezone: "UTC")
    ends_at = Time.current.beginning_of_week
    starts_at = ends_at - 7.days

    WeeklySummaryMailer.weekly_summary(
      user,
      recipient_email: "user@example.com",
      starts_at: starts_at,
      ends_at: ends_at
    )
  end
end
