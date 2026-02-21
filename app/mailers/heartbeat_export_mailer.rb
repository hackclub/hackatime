class HeartbeatExportMailer < ApplicationMailer
  def export_ready(user, recipient_email:, blob_signed_id:, filename:)
    blob = ActiveStorage::Blob.find_signed!(blob_signed_id)
    url_options = Rails.application.config.action_mailer.default_url_options || {}

    @user = user
    @filename = filename
    @download_url = ActiveStorage::Current.set(url_options:) do
      blob.url(expires_in: 7.days, disposition: "attachment")
    end

    mail(
      to: recipient_email,
      subject: "Your Hackatime heartbeat export is ready"
    )
  end
end
