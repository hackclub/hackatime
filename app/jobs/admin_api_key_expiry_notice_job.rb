# Emails every admin who still has an expiring admin API key (the keys that
# existed before scopes were introduced) once, listing when each will be revoked.
class AdminApiKeyExpiryNoticeJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    AdminApiKey.active.where.not(expires_at: nil).where(expiry_notice_sent_at: nil)
      .joins(:user).where(users: { admin_level: AdminApiKeyAuthentication::ADMIN_API_LEVELS })
      .includes(:user).group_by(&:user).each do |user, keys|
        recipient_email = user.email_addresses.order(:id).pick(:email)
        next if recipient_email.blank?

        AdminApiKeyMailer.expiry_notice(user, keys, recipient_email:).deliver_now
        AdminApiKey.where(id: keys.map(&:id)).update_all(expiry_notice_sent_at: Time.current)
      end
  end
end
