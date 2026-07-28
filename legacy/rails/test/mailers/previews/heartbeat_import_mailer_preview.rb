class HeartbeatImportMailerPreview < ActionMailer::Preview
  def import_completed
    user = User.first || User.new(username: "preview_user", timezone: "UTC")
    run = HeartbeatImportRun.find_by(state: :completed) ||
      HeartbeatImportRun.new(source_kind: :wakatime_dump, state: :completed)

    HeartbeatImportMailer.import_completed(
      user,
      run: run,
      recipient_email: "user@example.com"
    )
  end

  def import_failed
    user = User.first || User.new(username: "preview_user", timezone: "UTC")
    run = HeartbeatImportRun.find_by(state: :failed) ||
      HeartbeatImportRun.new(source_kind: :wakatime_dump, state: :failed)

    HeartbeatImportMailer.import_failed(
      user,
      run: run,
      recipient_email: "user@example.com"
    )
  end

  def wakatime_manual_download_required
    user = User.first || User.new(username: "preview_user", timezone: "UTC")

    HeartbeatImportMailer.wakatime_manual_download_required(
      user,
      recipient_email: "user@example.com"
    )
  end
end
