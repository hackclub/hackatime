class WeeklySummaryMailerPreview < ActionMailer::Preview
  def weekly_summary
    user_id = Clickhouse::Heartbeat.order(time: :desc).limit(1).pick(:user_id)
    user = (User.find_by(id: user_id) if user_id) || User.first
    ends_at = Time.current.beginning_of_week
    starts_at = ends_at - 7.days

    scope = Clickhouse::Heartbeat.for_user(user)
    if user && scope.where(time: starts_at.to_f...ends_at.to_f).none?
      latest_time = scope.order(time: :desc).limit(1).pick(:time)
      if latest_time
        ends_at = Time.at(latest_time).end_of_week + 1.day
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
