class WeeklySummaryMailerPreview < ActionMailer::Preview
  # Preview with real user data (uses the most recent week with activity)
  def weekly_summary
    user = User.joins(:heartbeats).distinct.first || User.first
    ends_at = Time.current.beginning_of_week
    starts_at = ends_at - 7.days

    # Try to find a week with actual heartbeat data for a better preview
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

  # Preview the zero-activity state
  def weekly_summary_empty
    user = User.first || User.new(username: "preview_user", timezone: "UTC")
    # Use a far-future range to guarantee no heartbeats
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
