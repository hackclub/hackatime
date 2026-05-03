class Settings::SetupController < Settings::BaseController
  def show
    render_settings_page(
      active_section: "setup",
      settings_update_path: my_settings_setup_path
    )
  end

  private

  def section_props
    api_key_token = @user.api_keys.last&.token

    {
      paths: paths_props,
      config_file: {
        content: generated_wakatime_config(api_key_token),
        has_api_key: api_key_token.present?,
        empty_message: "No API key is available yet. Rotate your API key from Privacy & Security to generate one.",
        api_key: api_key_token,
        api_url: "https://#{request.host_with_port}/api/hackatime/v1"
      }
    }
  end
end
