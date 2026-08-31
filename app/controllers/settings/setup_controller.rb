class Settings::SetupController < Settings::BaseController
  private

  def page_props
    api_key_token = @user.api_keys.last&.token

    {
      config_file: {
        content: generated_wakatime_config(api_key_token),
        has_api_key: api_key_token.present?,
        empty_message: "No API key is available yet. Rotate your API key from Privacy & Security to generate one.",
        api_key: api_key_token,
        api_url: "https://#{request.host_with_port}/api/hackatime/v1"
      }
    }
  end

  def generated_wakatime_config(api_key)
    return nil if api_key.blank?
    <<~CFG
      # put this in your ~/.wakatime.cfg file

      [settings]
      api_url = https://#{request.host_with_port}/api/hackatime/v1
      api_key = #{api_key}
      heartbeat_rate_limit_seconds = 30

      # any other wakatime configs you want to add: https://github.com/wakatime/wakatime-cli/blob/develop/USAGE.md#ini-config-file
    CFG
  end
end
