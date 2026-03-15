class WeeklySummaryMailerPreview < ActionMailer::Preview
  def weekly_summary
    user = User.joins(:heartbeats).distinct.first || User.first
    ends_at = Time.current.beginning_of_week
    starts_at = ends_at - 7.days

    if user&.heartbeats&.where(time: starts_at.to_f...ends_at.to_f)&.none?
      latest = user&.heartbeats&.order(time: :desc)&.first
      if latest
        ends_at = Time.at(latest.time).end_of_week + 1.day
        starts_at = ends_at - 7.days
      end
    end

    WeeklySummaryMailer.weekly_summary(
      user,
      recipient_email: "user@example.com",
      starts_at: starts_at,
      ends_at: ends_at
    )
  end

  def weekly_summary_empty
    user = User.first || User.new(username: "preview_user", timezone: "UTC")
    ends_at = 1.year.from_now.beginning_of_week
    starts_at = ends_at - 7.days

    WeeklySummaryMailer.weekly_summary(
      user,
      recipient_email: "user@example.com",
      starts_at: starts_at,
      ends_at: ends_at
    )
  end
end
