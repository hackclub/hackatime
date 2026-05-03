class Settings::PrivacyController < Settings::BaseController
  def show
    render_privacy
  end

  def update
    if @user.update(privacy_params)
      redirect_back(fallback_location: my_settings_privacy_path, notice: "Settings updated successfully")
    else
      flash.now[:error] = @user.errors.full_messages.to_sentence.presence || "Failed to update settings"
      render_privacy(status: :unprocessable_entity)
    end
  end

  def rotate_api_key
    new_api_key = @user.rotate_api_keys!

    flash[:rotated_api_key] = new_api_key.token
    redirect_to my_settings_privacy_path, notice: "API key rotated successfully"
  rescue => e
    report_error(e, message: "error rotate #{e.class.name}")
    redirect_to my_settings_privacy_path, alert: "Unable to rotate API key"
  end

  private

  def render_privacy(status: :ok)
    render_settings_page(
      active_section: "privacy",
      status: status
    )
  end

  def section_props
    {
      privacy_update_path: my_settings_privacy_update_path,
      user: user_props(keys: %i[allow_public_stats_lookup can_request_deletion]),
      paths: paths_props(keys: %i[rotate_api_key_path create_deletion_path]),
      rotated_api_key: flash[:rotated_api_key]
    }
  end

  def privacy_params
    params.require(:user).permit(:allow_public_stats_lookup)
  end
end
