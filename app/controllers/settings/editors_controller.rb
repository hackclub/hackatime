class Settings::EditorsController < Settings::BaseController
  def update
    if @user.update(editor_params)
      redirect_to my_settings_editors_path, notice: "Settings updated successfully"
    else
      flash.now[:error] = @user.errors.full_messages.to_sentence.presence || "Failed to update settings"
      render_settings_page(status: :unprocessable_entity)
    end
  end

  private

  def page_props
    { user: {
        hackatime_extension_text_type: @user.hackatime_extension_text_type,
        show_goals_in_statusbar: @user.show_goals_in_statusbar
      },
      options: base_options(keys: %i[extension_text_types]) }
  end

  def editor_params = params.require(:user).permit(:hackatime_extension_text_type, :show_goals_in_statusbar)
end
