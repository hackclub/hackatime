class AdminApiKeyMailer < ApplicationMailer
  def expiry_notice(user, keys, recipient_email:)
    @user = user
    @zone = ActiveSupport::TimeZone[user.timezone] || Time.find_zone!("UTC")
    @keys = keys.sort_by(&:expires_at)

    mail(
      to: recipient_email,
      subject: "Your Hackatime admin API #{"key".pluralize(@keys.size)} will be revoked on #{@keys.first.expires_at.in_time_zone(@zone).strftime("%-d %B %Y")}"
    )
  end
end
