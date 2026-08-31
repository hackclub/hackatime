class Settings::ImportsExportsController < Settings::BaseController
  private

  def section_props
    latest_import = @user.heartbeat_import_runs.latest_first.first
    if latest_import.present?
      latest_import = HeartbeatImportRunner.refresh_remote_run!(latest_import)
    end

    {
      data_export: InertiaRails.defer {
        {
          total_heartbeats: number_with_delimiter(@user.heartbeats.count),
          total_coding_time: @user.heartbeats.duration_simple,
          heartbeats_last_7_days: number_with_delimiter(@user.heartbeats.where("time >= ?", 7.days.ago.to_f).count),
          is_restricted: (@user.trust_level == "red")
        }
      },
      export_cooldown_minutes: export_cooldown_minutes,
      remote_import_cooldown_until: HeartbeatImportRunner.remote_import_cooldown_until(user: @user)&.iso8601,
      latest_heartbeat_import: HeartbeatImportRunner.serialize(latest_import),
      show_dev_import: Rails.env.development?
    }
  end

  def export_cooldown_minutes = My::HeartbeatsController::EXPORT_COOLDOWN.in_minutes.to_i
end
