class HeartbeatExportMailer < ApplicationMailer
  def export_ready(user, recipient_email:, file_path:, filename:)
    @user = user
    attachments[filename] = {
      mime_type: "application/json",
      content: File.binread(file_path)
    }

    mail(
      to: recipient_email,
      subject: "Your Hackatime heartbeat export is ready"
    )
  end
end
