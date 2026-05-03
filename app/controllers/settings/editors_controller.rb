class Settings::EditorsController < Settings::BaseController
  def show
    render_editors
  end

  def update
    if @user.update(editor_params)
      redirect_to my_settings_editors_path, notice: "Settings updated successfully"
    else
      flash.now[:error] = @user.errors.full_messages.to_sentence.presence || "Failed to update settings"
      render_editors(status: :unprocessable_entity)
    end
  end

  private

  def render_editors(status: :ok)
    render_settings_page(
      active_section: "editors",
      settings_update_path: my_settings_editors_path,
      status: status
    )
  end

  def section_props
    {
      settings_update_path: my_settings_editors_path,
      user: user_props,
      options: base_options
    }
  end

  def editor_params
    params.require(:user).permit(:hackatime_extension_text_type, :show_goals_in_statusbar)
  end
end
