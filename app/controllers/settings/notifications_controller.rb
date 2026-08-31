class Settings::NotificationsController < Settings::BaseController
  def update
    list = "weekly_summary"
    enabled = params.dig(:user, :weekly_summary_email_enabled)

    begin
      if enabled == "1" || enabled == true
        @user.subscribe(list) unless @user.subscribed?(list)
      else
        @user.unsubscribe(list) if @user.subscribed?(list)
      end

      redirect_to my_settings_notifications_path, notice: "Settings updated successfully"
    rescue => e
      report_error(e, message: "Failed to update notification settings")
      flash.now[:error] = "Failed to update settings, sorry :("
      render_settings_page(status: :unprocessable_entity)
    end
  end

  private

  def page_props
    { user: { weekly_summary_email_enabled: @user.subscribed?("weekly_summary") } }
  end
end
