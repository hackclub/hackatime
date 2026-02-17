class Settings::DataController < Settings::BaseController
  def show
    render_data
  end

  def migrate_heartbeats
    redirect_to my_settings_data_path, alert: "Legacy Hackatime migration is no longer available"
  end

  private

  def render_data(status: :ok)
    render_settings_page(
      active_section: "data",
      settings_update_path: my_settings_profile_path,
      status: status
    )
  end
end
