class HeartbeatImportMailer < ApplicationMailer
  def import_completed(user, run:, recipient_email:)
    @user = user
    @run = run
    @settings_url = my_settings_imports_exports_url
    @source_name = HeartbeatImportRunner.import_source_name(run)

    mail(
      to: recipient_email,
      subject: "Your #{@source_name} import is complete"
    )
  end

  def import_failed(user, run:, recipient_email:)
    @user = user
    @run = run
    @settings_url = my_settings_imports_exports_url
    @source_name = HeartbeatImportRunner.import_source_name(run)

    mail(
      to: recipient_email,
      subject: "Your #{@source_name} import failed"
    )
  end

  def wakatime_manual_download_required(user, recipient_email:)
    @user = user
    @manual_download_url = wakatime_download_link_my_heartbeat_imports_url

    mail(
      to: recipient_email,
      subject: "Your WakaTime import needs an export link"
    )
  end
end
