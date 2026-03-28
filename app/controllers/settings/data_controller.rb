class Settings::DataController < Settings::BaseController
  def show
    render_data
  end

  private

  def format_duration_simple(seconds)
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60

    if hours > 1
      "#{hours} hrs"
    elsif hours == 1
      "1 hr"
    elsif minutes > 0
      "#{minutes} min"
    else
      "0 min"
    end
  end

  def render_data(status: :ok)
    render_settings_page(
      active_section: "data",
      settings_update_path: my_settings_profile_path,
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
      user: user_props,
      paths: paths_props,
      data_export: InertiaRails.defer {
        {
          total_heartbeats: number_with_delimiter(@user.heartbeats.count),
          total_coding_time: format_duration_simple(StatsClient.duration(user_id: @user.id)["total_seconds"].to_i),
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
