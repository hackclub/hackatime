class Admin::CacheController < Admin::BaseController
  def clear
    unless current_user&.admin_level_superadmin?
      redirect_to root_path, alert: "Not authorized"
      return
    end

    Rails.cache.clear
    redirect_back fallback_location: root_path, notice: "Cache cleared successfully"
  end
end
