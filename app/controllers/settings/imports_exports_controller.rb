class Settings::ImportsExportsController < Settings::BaseController
  def show
    render_imports_exports
  end

  private

  def render_imports_exports(status: :ok)
    render_settings_page(
      active_section: "imports_exports",
      status: status
    )
  end

  def section_props
    imports_enabled = Flipper.enabled?(:imports, @user)
    latest_import = @user.heartbeat_import_runs.latest_first.first
    if latest_import.present?
      latest_import = HeartbeatImportRunner.refresh_remote_run!(latest_import)
    end

    {
      paths: paths_props(keys: %i[
        export_all_heartbeats_path
        export_range_heartbeats_path
        create_heartbeat_import_path
      ]),
      data_export: InertiaRails.defer {
        {
          total_heartbeats: number_with_delimiter(@user.heartbeats.count),
          total_coding_time: @user.heartbeats.duration_simple,
          heartbeats_last_7_days: number_with_delimiter(@user.heartbeats.where("time >= ?", 7.days.ago.to_f).count),
          is_restricted: (@user.trust_level == "red")
        }
      },
      imports_enabled: imports_enabled,
      remote_import_cooldown_until: HeartbeatImportRunner.remote_import_cooldown_until(user: @user)&.iso8601,
      latest_heartbeat_import: HeartbeatImportRunner.serialize(latest_import),
      ui: {
        show_dev_import: Rails.env.development?,
        show_imports: imports_enabled
      }
    }
  end
end
