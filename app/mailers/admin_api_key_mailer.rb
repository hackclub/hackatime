class AdminApiKeyMailer < ApplicationMailer
  def expiry_notice(user, keys, recipient_email:)
    @user = user
    zone = ActiveSupport::TimeZone[user.timezone] || Time.find_zone!("UTC")
    @keys = keys.sort_by(&:expires_at).map do |key|
      { name: key.name, token_preview: key.token_preview, expires_at: key.expires_at.in_time_zone(zone).strftime("%-d %B %Y at %H:%M %Z") }
    end
    @new_key_url = new_admin_admin_api_key_url

    mail(
      to: recipient_email,
      subject: "Your Hackatime admin API #{"key".pluralize(@keys.size)} will be revoked on #{keys.map(&:expires_at).min.in_time_zone(zone).strftime("%-d %B %Y")}"
    )
  end
end
