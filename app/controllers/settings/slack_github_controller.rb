class Settings::SlackGithubController < Settings::BaseController
  def show
    render_slack_github
  end

  def update
    if @user.update(slack_github_params)
      @user.update_slack_status if @user.uses_slack_status?
      redirect_to my_settings_slack_github_path, notice: "Settings updated successfully"
    else
      flash.now[:error] = @user.errors.full_messages.to_sentence.presence || "Failed to update settings"
      render_slack_github(status: :unprocessable_entity)
    end
  end

  private

  def render_slack_github(status: :ok)
    render_settings_page(
      active_section: "slack_github",
      status: status
    )
  end

  def section_props
    can_enable_slack_status = @user.slack_access_token.present? && @user.slack_scopes.include?("users.profile:write")
    enabled_sailors_logs = SailorsLogNotificationPreference.where(
      slack_uid: @user.slack_uid,
      enabled: true,
    ).where.not(slack_channel_id: SailorsLog::DEFAULT_CHANNELS)
    channel_ids = enabled_sailors_logs.pluck(:slack_channel_id)

    {
      settings_update_path: my_settings_slack_github_path,
      user: user_props(keys: %i[uses_slack_status]),
      slack: {
        can_enable_status: can_enable_slack_status,
        notification_channels: channel_ids.map { |channel_id|
          channel_name = SlackChannel.find_by_id(channel_id) rescue nil
          {
            id: channel_id,
            label: channel_name.present? ? "##{channel_name}" : "##{channel_id}",
            url: "https://hackclub.slack.com/archives/#{channel_id}"
          }
        }
      },
      github: {
        connected: @user.github_uid.present?,
        username: @user.github_username,
        profile_url: (@user.github_username.present? ? "https://github.com/#{@user.github_username}" : nil)
      },
      paths: paths_props(keys: %i[slack_auth_path github_auth_path github_unlink_path])
    }
  end

  def slack_github_params
    params.require(:user).permit(:uses_slack_status)
  end
end
