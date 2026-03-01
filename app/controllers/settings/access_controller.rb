class Settings::AccessController < Settings::BaseController
  def show
    render_access
  end

  def update
    if @user.update(access_params)
      PosthogService.capture(@user, "settings_updated", { fields: access_params.keys })
      redirect_to my_settings_access_path, notice: "Settings updated successfully"
    else
      flash.now[:error] = @user.errors.full_messages.to_sentence.presence || "Failed to update settings"
      render_access(status: :unprocessable_entity)
    end
  end

  def rotate_api_key
    @user.api_keys.transaction do
      @user.api_keys.destroy_all

      new_api_key = @user.api_keys.create!(name: "Hackatime key")

      PosthogService.capture(@user, "api_key_rotated")
      render json: { token: new_api_key.token }, status: :ok
    end
  rescue => e
    Sentry.capture_exception(e)
    Rails.logger.error("error rotate #{e.class.name} #{e.message}")
    render json: { error: "cant rotate" }, status: :unprocessable_entity
  end

  private

  def render_access(status: :ok)
    render_settings_page(
      active_section: "access",
      settings_update_path: my_settings_access_path,
      status: status
    )
  end

  def access_params
    params.require(:user).permit(:hackatime_extension_text_type)
  end
end
