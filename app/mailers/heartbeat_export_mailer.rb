class HeartbeatExportMailer < ApplicationMailer
  def export_ready(user, recipient_email:, blob:, filename:)
    @user = user
    @filename = filename
    @download_url = rails_blob_url(blob, disposition: "attachment")

    mail(
      to: recipient_email,
      subject: "Your Hackatime heartbeat export is ready"
    )
  end
end
