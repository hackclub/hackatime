# frozen_string_literal: true

module AdminApiKeyAuthentication
  extend ActiveSupport::Concern

  ADMIN_API_LEVELS = %w[admin superadmin viewer ultraadmin].freeze

  private

  def auth_admin_api_key(token)
    key = AdminApiKey.active.includes(:user).find_by(token: token) or return false
    user = key.user
    unless admin_api_user?(user)
      key.revoke!
      return false
    end

    @admin_api_key, @current_user = key, user
    true
  end

  def admin_api_user?(user) = user&.authentication_allowed? && user.admin_level.in?(ADMIN_API_LEVELS)
end
