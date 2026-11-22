class Settings::AppearanceController < Settings::BaseController
  def update_theme
    update_user_settings(
      theme_params,
      redirect_location: my_settings_appearance_path,
      back: true,
      clear_history: true
    )
  end

  private

  def page_props
    { user: { theme: @user.theme }, options: base_options(keys: %i[themes]) }
  end

  def theme_params = params.require(:user).permit(:theme)
end
