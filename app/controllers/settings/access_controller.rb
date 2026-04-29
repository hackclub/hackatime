class Settings::AccessController < Settings::BaseController
  def show
    render_access
  end

  def update
    if @user.update(access_params)
      redirect_to my_settings_access_path, notice: "Settings updated successfully"
    else
      flash.now[:error] = @user.errors.full_messages.to_sentence.presence || "Failed to update settings"
      render_access(status: :unprocessable_entity)
    end
  end

  def rotate_api_key
    new_api_key = @user.rotate_api_keys!

    flash[:rotated_api_key] = new_api_key.token
    redirect_to my_settings_access_path, notice: "API key rotated successfully"
  rescue => e
    report_error(e, message: "error rotate #{e.class.name}")
    redirect_to my_settings_access_path, alert: "Unable to rotate API key"
  end

  private

  def render_access(status: :ok)
    render_settings_page(
      active_section: "access",
      settings_update_path: my_settings_access_path,
      status: status
    )
  end

  def section_props
    api_key_token = @user.api_keys.last&.token

    {
      settings_update_path: my_settings_access_path,
      user: user_props,
      options: base_options,
      paths: paths_props,
      config_file: {
        content: generated_wakatime_config(api_key_token),
        has_api_key: api_key_token.present?,
        empty_message: "No API key is available yet. Rotate your API key to generate one.",
        api_key: api_key_token,
        api_url: "https://#{request.host_with_port}/api/hackatime/v1"
      },
      rotated_api_key: flash[:rotated_api_key]
    }
  end

  def access_params
    params.require(:user).permit(:hackatime_extension_text_type)
  end
end
