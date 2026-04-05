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

  def section_props
    can_enable_slack_status = @user.slack_access_token.present? && @user.slack_scopes.include?("users.profile:write")
    enabled_sailors_logs = SailorsLogNotificationPreference.where(
      slack_uid: @user.slack_uid,
      enabled: true,
    ).where.not(slack_channel_id: SailorsLog::DEFAULT_CHANNELS)
    channel_ids = enabled_sailors_logs.pluck(:slack_channel_id)
    pending_email_requests = @user.email_verification_requests.valid.order(created_at: :desc)
    verified_emails = @user.email_addresses.map { |email|
      {
        email: email.email,
        source: email.source&.humanize || "Unknown",
        can_unlink: @user.can_delete_email_address?(email),
        pending: false,
        can_resend: false,
        resend_cooldown_seconds: 0
      }
    }

    pending_emails = pending_email_requests.map { |request|
      {
        email: request.email,
        source: "Pending verification",
        can_unlink: true,
        pending: true,
        can_resend: request.resend_available?,
        resend_cooldown_seconds: request.resend_cooldown_seconds
      }
    }

    {
      settings_update_path: my_settings_integrations_path,
      user: user_props,
      slack: {
        can_enable_status: can_enable_slack_status,
        notification_channels: channel_ids.map { |channel_id|
          {
            id: channel_id,
            label: "##{channel_id}",
            url: "https://hackclub.slack.com/archives/#{channel_id}"
          }
        }
      },
      github: {
        connected: @user.github_uid.present?,
        username: @user.github_username,
        profile_url: (@user.github_username.present? ? "https://github.com/#{@user.github_username}" : nil)
      },
      emails: (verified_emails + pending_emails),
      paths: paths_props
    }
  end

  def integrations_params
    params.require(:user).permit(:uses_slack_status)
  end
end
