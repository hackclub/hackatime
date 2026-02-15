class Settings::ProfileController < Settings::BaseController
  def show
    render_profile
  end

  def update
    if @user.update(profile_params)
      PosthogService.capture(@user, "settings_updated", { fields: profile_params.keys })
      redirect_to my_settings_profile_path, notice: "Settings updated successfully"
    else
      flash.now[:error] = @user.errors.full_messages.to_sentence.presence || "Failed to update settings"
      render_profile(status: :unprocessable_entity)
    end
  end

  private

  def render_profile(status: :ok)
    render_settings_page(
      active_section: "profile",
      settings_update_path: my_settings_profile_path,
      status: status
    )
  end

  def profile_params
    params.require(:user).permit(
      :timezone,
      :country_code,
      :allow_public_stats_lookup,
      :username,
      :theme,
    )
  end
end
