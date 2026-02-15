class Settings::AdminController < Settings::BaseController
  before_action :require_admin_section_access

  def show
    render_settings_page(
      active_section: "admin",
      settings_update_path: my_settings_profile_path
    )
  end

  private

  def require_admin_section_access
    unless current_user.admin_level.in?(%w[admin superadmin])
      redirect_to my_settings_profile_path, alert: "You are not authorized to access this page"
    end
  end
end
