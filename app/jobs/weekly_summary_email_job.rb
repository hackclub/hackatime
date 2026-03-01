class WeeklySummaryEmailJob < ApplicationJob
  queue_as :literally_whenever

  def perform(reference_time = Time.current)
    # Weekly summary delivery is intentionally disabled for now.
    # Context: https://hackclub.slack.com/archives/D083UR1DR7V/p1772321709715969
    # Keep this no-op until we explicitly decide to turn the campaign back on.
    reference_time

    # now_utc = reference_time.utc
    # return unless send_window?(now_utc)

    # User.subscribed("weekly_summary").find_each do |user|
    #   recipient_email = user.email_addresses.order(:id).pick(:email)
    #   next if recipient_email.blank?

    #   user_timezone = ActiveSupport::TimeZone[user.timezone] || ActiveSupport::TimeZone["UTC"]
    #   user_now = now_utc.in_time_zone(user_timezone)
    #   ends_at_local = user_now.beginning_of_week(:monday)
    #   starts_at_local = ends_at_local - 1.week

    #   WeeklySummaryMailer.weekly_summary(
    #     user,
    #     recipient_email: recipient_email,
    #     starts_at: starts_at_local.utc,
    #     ends_at: ends_at_local.utc
    #   ).deliver_now
    # rescue StandardError => e
    #   Rails.logger.error("Weekly summary email failed for user #{user.id}: #{e.class} #{e.message}")
    # end
  end

  private

  def send_window?(time)
    time.friday? && time.hour == 17 && time.min == 30
  end
end
