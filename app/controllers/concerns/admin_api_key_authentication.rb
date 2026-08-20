# frozen_string_literal: true

module AdminApiKeyAuthentication
  extend ActiveSupport::Concern

  ADMIN_API_LEVELS = %w[admin superadmin viewer ultraadmin].freeze

  private

  def auth_admin_api_key(token)
    key = AdminApiKey.find_active_by_token(token) or return false
    user = key.user
    unless admin_api_user?(user)
      key.revoke!
      return false
    end

    @admin_api_key, @current_user = key, user
    true
  end

  def admin_api_user?(user) = user&.admin_level.in?(ADMIN_API_LEVELS)
end
