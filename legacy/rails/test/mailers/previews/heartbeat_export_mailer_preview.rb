class HeartbeatExportMailerPreview < ActionMailer::Preview
  def export_ready
    user = User.first || User.new(username: "preview_user", timezone: "UTC")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("preview"),
      filename: "heartbeats_export.zip",
      content_type: "application/zip"
    )

    HeartbeatExportMailer.export_ready(
      user,
      recipient_email: "user@example.com",
      blob_signed_id: blob.signed_id,
      filename: "heartbeats_export.zip"
    )
  end
end
