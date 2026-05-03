class Settings::ProfileController < Settings::BaseController
  def show
    render_profile
  end

  def update_region
    update_section(region_params)
  end

  def update_username
    update_section(username_params)
  end

  private

  def render_profile(status: :ok)
    render_settings_page(
      active_section: "profile",
      status: status
    )
  end

  def section_props
    {
      username_max_length: User::USERNAME_MAX_LENGTH,
      user: user_props(keys: %i[country_code timezone username]),
      options: base_options(keys: %i[countries timezones]),
      profile_url: (@user.username.present? ? "https://hackati.me/#{@user.username}" : nil),
      emails: @user.email_addresses.map { |email|
        {
          email: email.email,
          source: email.source&.humanize || "Unknown",
          can_unlink: @user.can_delete_email_address?(email)
        }
      }
    }
  end

  def update_section(permitted_params)
    if @user.update(permitted_params)
      redirect_back(fallback_location: my_settings_profile_path, notice: "Settings updated successfully")
    else
      flash.now[:error] = @user.errors.full_messages.to_sentence.presence || "Failed to update settings"
      render_profile(status: :unprocessable_entity)
    end
  end

  def region_params
    permitted = params.require(:user).permit(:timezone, :country_code)
    permitted[:country_code] = nil if permitted[:country_code].blank?
    permitted
  end

  def username_params
    params.require(:user).permit(:username)
  end
end
