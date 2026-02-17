class Settings::IntegrationsController < Settings::BaseController
  def show
    render_integrations
  end

  def update
    if @user.update(integrations_params)
      @user.update_slack_status if @user.uses_slack_status?
      PosthogService.capture(@user, "settings_updated", { fields: integrations_params.keys })
      redirect_to my_settings_integrations_path, notice: "Settings updated successfully"
    else
      flash.now[:error] = @user.errors.full_messages.to_sentence.presence || "Failed to update settings"
      render_integrations(status: :unprocessable_entity)
    end
  end

  private

  def render_integrations(status: :ok)
    render_settings_page(
      active_section: "integrations",
      settings_update_path: my_settings_integrations_path,
      status: status
    )
  end

  def integrations_params
    params.require(:user).permit(:uses_slack_status)
  end
end
