class Settings::DataController < Settings::BaseController
  def show
    render_data
  end

  def migrate_heartbeats
    unless Flipper.enabled?(:hackatime_v1_import)
      redirect_to my_settings_data_path, alert: "Hackatime v1 import is currently disabled"
      return
    end

    MigrateUserFromHackatimeJob.perform_later(@user.id)
    redirect_to my_settings_data_path, notice: "Heartbeats & api keys migration started"
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
