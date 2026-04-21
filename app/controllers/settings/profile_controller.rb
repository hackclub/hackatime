class Settings::ProfileController < Settings::BaseController
  def show
    render_profile
  end

  def update_region
    update_section(region_params)
  end

  def update_privacy
    update_section(privacy_params)
  end

  def update_username
    update_section(username_params)
  end

  def update_theme
    update_section(theme_params)
  end

  private

  def render_profile(status: :ok)
    render_settings_page(
      active_section: "profile",
      settings_update_path: my_settings_profile_path,
      status: status
    )
  end

  def section_props
    {
      region_update_path: my_settings_profile_region_path,
      privacy_update_path: my_settings_profile_privacy_path,
      username_update_path: my_settings_profile_username_path,
      theme_update_path: my_settings_profile_theme_path,
      username_max_length: User::USERNAME_MAX_LENGTH,
      user: user_props,
      options: base_options,
      profile_url: (@user.username.present? ? "https://hackati.me/#{@user.username}" : nil)
    }
  end

  def update_section(permitted_params)
    if @user.update(permitted_params)
      PosthogService.capture(@user, "settings_updated", { fields: permitted_params.keys })
      redirect_back(fallback_location: my_settings_profile_path, notice: "Settings updated successfully")
    else
      flash.now[:error] = @user.errors.full_messages.to_sentence.presence || "Failed to update settings"
      render_profile(status: :unprocessable_entity)
    end
  end

  def region_params
    permitted = params.require(:user).permit(:timezone, :country_code)
    permitted[:country_code] = nil if permitted[:country_code].blank?
    permitted
  end

  def privacy_params
    params.require(:user).permit(:allow_public_stats_lookup)
  end

  def username_params
    params.require(:user).permit(:username)
  end

  def theme_params
    params.require(:user).permit(:theme)
  end
end
