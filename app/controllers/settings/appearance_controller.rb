class Settings::AppearanceController < Settings::BaseController
  def update_theme
    if @user.update(theme_params)
      redirect_back(fallback_location: my_settings_appearance_path, notice: "Settings updated successfully")
    else
      flash.now[:error] = @user.errors.full_messages.to_sentence.presence || "Failed to update settings"
      render_settings_page(status: :unprocessable_entity)
    end
  end

  private

  def section_props
    { user: user_props(keys: %i[theme]), options: base_options(keys: %i[themes]) }
  end

  def theme_params = params.require(:user).permit(:theme)
end
