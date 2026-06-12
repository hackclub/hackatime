class Settings::ProfileController < Settings::BaseController
  def show = render_profile
  def update_region = update_section(region_params)
  def update_display_name = update_section(display_name_params)
  def update_username = update_section(username_params)

  private

  def render_profile(status: :ok)
    render_settings_page(active_section: "profile", status: status)
  end

  def section_props
    options = base_options(keys: %i[countries timezones])
    options[:timezones] = pin_current_timezone(options[:timezones])
    {
      username_max_length: User::USERNAME_MAX_LENGTH,
      display_name_max_length: User::DISPLAY_NAME_MAX_LENGTH,
      user: user_props(keys: %i[country_code timezone display_name display_name_override username]),
      options: options,
      profile_url: (@user.username.present? ? "https://hackati.me/#{@user.username}" : nil),
      emails: @user.email_addresses.map { |email|
        { email: email.email,
          source: email.source&.humanize || "Unknown",
          can_unlink: @user.can_delete_email_address?(email) }
      }
    }
  end

  # if the user is using a legacy TZ, we don't want to delete it from the list!
  def pin_current_timezone(timezones)
    current = @user.timezone
    return timezones if current.blank? || timezones.any? { |t| t[:value] == current }

    offset = ActiveSupport::TimeZone[current]&.now&.formatted_offset
    label = offset ? "#{current} (UTC#{offset})" : current
    [ { label: label, value: current } ] + timezones
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

  def display_name_params = params.require(:user).permit(:display_name_override)
  def username_params = params.require(:user).permit(:username)
end
