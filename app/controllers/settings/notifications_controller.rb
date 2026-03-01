class Settings::NotificationsController < Settings::BaseController
  def show
    render_notifications
  end

  def update
    enabled = params.dig(:user, :weekly_summary_email_enabled)
    @user.weekly_summary_email_enabled = enabled == "1" || enabled == true

    if @user.save
      PosthogService.capture(@user, "settings_updated", { fields: [ "weekly_summary_email_enabled" ] })
      redirect_to my_settings_notifications_path, notice: "Settings updated successfully"
    else
      flash.now[:error] = "Failed to update settings, sorry :("
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
end
