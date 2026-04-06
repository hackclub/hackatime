class Admin::BaseController < ApplicationController
  before_action :authenticate_admin!

  private

  def authenticate_admin!
    unless current_user && current_user.admin_level.in?([ "admin", "superadmin", "viewer", "ultraadmin" ])
      redirect_to root_path, alert: "You are not authorized to access this page."
    end
  end

  def require_admin_level!(*levels)
    levels = levels.map(&:to_s)
    levels << "ultraadmin" unless levels.include?("ultraadmin")
    unless current_user && current_user.admin_level.in?(levels)
      redirect_to root_path, alert: "no perms lmaooo"
    end
  end
end
