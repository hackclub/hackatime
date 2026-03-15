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
      badges: badges_props
    }
  end
end
