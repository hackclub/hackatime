class Admin::BaseController < ApplicationController
  ADMIN_NAV_LEVELS = %w[admin superadmin viewer ultraadmin].freeze

  before_action :authenticate_admin!

  private

  def authenticate_admin!
    unless current_user&.admin_level.in?(ADMIN_NAV_LEVELS)
      redirect_to root_path, alert: "You are not authorized to access this page."
    end
  end

  def require_admin_level!(*levels)
    levels = levels.map(&:to_s)
    levels << "ultraadmin" unless levels.include?("ultraadmin")
    unless current_user&.admin_level.in?(levels)
      redirect_to root_path, alert: "You are not authorized to access this page."
    end
  end
end
