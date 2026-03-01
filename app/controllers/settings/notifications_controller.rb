class Settings::NotificationsController < Settings::BaseController
  def show
    render_notifications
  end

  def update
    list = "weekly_summary"
    enabled = params.dig(:user, :weekly_summary_email_enabled)

    begin
      if enabled == "1" || enabled == true
        @user.subscribe(list) unless @user.subscribed?(list)
      else
        @user.unsubscribe(list) if @user.subscribed?(list)
      end

      PosthogService.capture(@user, "settings_updated", { fields: [ "weekly_summary_email_enabled" ] })
      redirect_to my_settings_notifications_path, notice: "Settings updated successfully"
    rescue => e
      Rails.logger.error("Failed to update notification settings: #{e.message}")
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
