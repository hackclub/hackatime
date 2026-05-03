# frozen_string_literal: true

# UserPolicy covers actions performed *on* a User record (changing trust,
# impersonation, admin-level changes) plus a few self-acting predicates
# that gate API access for the current user (export heartbeats, request
# deletion, etc).
#
# `record` is the target user. For self-acting predicates the policy is
# typically built with `record == user`.
class UserPolicy < ApplicationPolicy
  # ---- Trust level changes ----

  # Set trust to anything that isn't `red`.
  def update_trust_level?
    admin? && record != user
  end

  # Set trust to `red` ("convict"). Tightened relative to update_trust_level?.
  def convict?
    superadmin? && record != user
  end

  # ---- Impersonation ----

  # Cascading impersonation rules:
  #   - admin    -> can impersonate default + viewer
  #   - superadmin -> can impersonate default + viewer + admin
  #   - ultraadmin -> can impersonate default + viewer + admin + superadmin
  #   - nobody can impersonate ultraadmin
  #   - nobody can impersonate themselves
  def impersonate?
    return false unless any_admin?
    return false if record == user
    return false if record.admin_level_ultraadmin?
    return false if record.admin_level_superadmin? && !ultraadmin?
    return false if record.admin_level_admin? && !superadmin?

    true
  end

  # ---- Admin level (role) changes ----

  # Whether `user` may change `record`'s admin level.
  # Self-edit is always blocked. Granting `ultraadmin` is ultraadmin-only.
  # Used by both web `Admin::AdminUsersController#update` and the API
  # `Api::Admin::V1::PermissionsController#update`.
  def change_admin_level?
    superadmin? && record != user
  end

  # May `user` grant the `ultraadmin` role to `record`?
  # Required addition to `change_admin_level?` when the new level is
  # `ultraadmin`.
  def grant_ultraadmin?
    ultraadmin? && record != user
  end

  # ---- Authenticated API soft-ban ----

  # Whether the user may use the OAuth-authenticated API at all. Red trust
  # users are soft-banned.
  def use_authenticated_api?
    signed_in? && !red?
  end

  # Whether the user may export their heartbeats. Red trust users are
  # blocked.
  def export_heartbeats?
    signed_in? && !red?
  end

  # ---- Heartbeat import cooldowns ----

  # Superadmins (and ultraadmins) skip the remote-import cooldown for
  # debugging.
  def skip_import_cooldown?
    superadmin?
  end
end
