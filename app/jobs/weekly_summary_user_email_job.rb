class WeeklySummaryUserEmailJob < ApplicationJob
  queue_as :literally_whenever

  def perform(user_id, now_utc_iso8601)
    user = User.find_by(id: user_id)
    return if user.nil?
    return unless user.subscribed?("weekly_summary")

    recipient_email = user.email_addresses.order(:id).pick(:email)
    return if recipient_email.blank?

    now_utc = Time.zone.parse(now_utc_iso8601)
    user_timezone = ActiveSupport::TimeZone[user.timezone] || ActiveSupport::TimeZone["UTC"]
    user_now = now_utc.in_time_zone(user_timezone)
    ends_at_local = user_now.beginning_of_week(:monday)
    starts_at_local = ends_at_local - 1.week

    WeeklySummaryMailer.weekly_summary(
      user,
      recipient_email: recipient_email,
      starts_at: starts_at_local.utc,
      ends_at: ends_at_local.utc
    ).deliver_now
  end
end
