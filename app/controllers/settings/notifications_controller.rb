class Settings::NotificationsController < Settings::BaseController
  def show
    render_notifications
  end

  def update
    if @user.update(notifications_params)
      PosthogService.capture(@user, "settings_updated", { fields: notifications_params.keys })
      redirect_to my_settings_notifications_path, notice: "Settings updated successfully"
    else
      flash.now[:error] = @user.errors.full_messages.to_sentence.presence || "Failed to update settings"
      render_notifications(status: :unprocessable_entity)
    end
  end

  private

  def render_notifications(status: :ok)
    render_settings_page(
      active_section: "notifications",
      settings_update_path: my_settings_notifications_path,
      status: status
    )
  end

  def notifications_params
    params.require(:user).permit(:weekly_summary_email_enabled)
  end
end
