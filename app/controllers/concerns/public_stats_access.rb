# frozen_string_literal: true

# Lets admins read a user's stats on the public stats endpoints even when that
# user has turned off `allow_public_stats_lookup`.
#
# These endpoints are anonymously accessible, so the admin credential is only
# ever read from the `Authorization: Bearer` header. It is deliberately never
# read from `?api_key=` (which several of these endpoints accept for ordinary
# user keys) so a privileged token cannot end up in a URL, log line or referrer.
#
# This intentionally does NOT assign `@current_user`. `ApplicationController#current_user`
# memoises into that ivar, so assigning it would silently authenticate the whole
# request as the admin for every other `current_user` check in the request cycle.
module PublicStatsAccess
  extend ActiveSupport::Concern

  private

  # True when the caller may bypass the target's public stats preference.
  def admin_stats_access?
    return true if current_user&.can_view_private_stats?

    admin_stats_viewer.present?
  end

  # The admin User behind the request's bearer token, or nil.
  def admin_stats_viewer
    return @admin_stats_viewer if defined?(@admin_stats_viewer)

    @admin_stats_viewer = resolve_admin_stats_viewer
  end

  def resolve_admin_stats_viewer
    scheme, token = request.headers["Authorization"].to_s.split(/\s+/, 2)
    return nil unless scheme&.casecmp?("Bearer") && token.present?

    admin_viewer_from_api_key(token) || admin_viewer_from_oauth(token)
  end

  def admin_viewer_from_api_key(token)
    key = AdminApiKey.active.includes(:user).find_by(token: token)
    return nil unless key

    user = key.user
    # Mirrors AdminApiKeyAuthentication: a key whose owner lost admin is dead.
    return user if user&.can_view_private_stats?

    key.revoke!
    nil
  end

  def admin_viewer_from_oauth(token)
    access_token = Doorkeeper::AccessToken.by_token(token)
    return nil unless access_token&.acceptable?([ OauthApplication::ADMIN_SCOPE ])

    application = access_token.application
    return nil unless application&.admin_scope? && application.confidential? && application.verified?

    user = User.find_by(id: access_token.resource_owner_id)
    user if user&.can_view_private_stats?
  end
end
