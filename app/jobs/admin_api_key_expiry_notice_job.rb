# Run by hand after deploy. Each key is only ever included in one email.
class AdminApiKeyExpiryNoticeJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  queue_as :literally_whenever
  good_job_control_concurrency_with(total_limit: 1)

  def perform
    AdminApiKey.active.where.not(expires_at: nil).where(expiry_notice_sent_at: nil)
      .joins(:user).where(users: { admin_level: AdminApiKeyAuthentication::ADMIN_API_LEVELS })
      .includes(:user).group_by(&:user).each do |user, keys|
        recipient_email = user.email_addresses.order(:id).pick(:email)
        next if recipient_email.blank?

        # Marking the keys and enqueueing the mail commit together, and the mail
        # delivery job retries on its own, so a retry of this job never resends.
        AdminApiKey.transaction do
          AdminApiKey.where(id: keys.map(&:id)).update_all(expiry_notice_sent_at: Time.current)
          AdminApiKeyMailer.expiry_notice(user, keys, recipient_email:).deliver_later
        end
      end
  end
end
