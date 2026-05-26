# frozen_string_literal: true

# Shared signin/admin authorization helpers used by HTML controllers
# (sessions, account_merger, settings/*, admin/*, my/*).
#
# These helpers redirect on failure and return falsy so callers can do
# `return unless require_signed_in!(...)` or chain off of them.
module AuthHelpers
  extend ActiveSupport::Concern

  ADMIN_LEVELS = %w[admin superadmin ultraadmin].freeze
  SUPERADMIN_LEVELS = %w[superadmin ultraadmin].freeze

  # Redirects unsigned-in users; returns true if signed in.
  def require_signed_in!(message = "Please sign in first", redirect_path: root_path)
    return true if current_user
    redirect_to redirect_path, alert: message
    false
  end

  def require_admin!(redirect_path: root_path, alert: "You are not authorized to access this page")
    unless current_user&.admin_level.in?(ADMIN_LEVELS)
      redirect_to redirect_path, alert: alert
      return false
    end
    true
  end

  def require_superadmin_html!(redirect_path: root_path, alert: "You are not authorized to access this page")
    unless current_user&.admin_level.in?(SUPERADMIN_LEVELS)
      redirect_to redirect_path, alert: alert
      return false
    end
    true
  end

  def require_ultraadmin!(redirect_path: root_path, alert: "You are not authorized to access this page.")
    unless current_user&.admin_level == "ultraadmin"
      redirect_to redirect_path, alert: alert
      return false
    end
    true
  end
end
