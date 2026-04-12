class Settings::BadgesController < Settings::BaseController
  def show
    render_settings_page(
      active_section: "badges",
      settings_update_path: my_settings_profile_path
    )
  end

  private

  def section_props
    {
      options: options_props,
      badges: badges_props,
      allow_public_stats_lookup: @user.allow_public_stats_lookup,
      settings_update_path: my_settings_profile_path
    }
  end
end
