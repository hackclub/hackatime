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
  # An ultraadmin's trust may only be changed by another ultraadmin —
  # otherwise a lower tier could (e.g.) flip them to `yellow` or undo a
  # `green` mark, which violates the role hierarchy.
  def update_trust_level?
    admin? && record != user && !ultraadmin_target_shielded?
  end

  # Set trust to `red` ("convict"). Tightened relative to update_trust_level?.
  # `red` revokes API access (see `use_authenticated_api?`), so allowing a
  # superadmin to convict an ultraadmin would be a back-door demotion of
  # the higher tier. Block it.
  def convict?
    superadmin? && record != user && !ultraadmin_target_shielded?
  end

  # Cascading impersonation rules:
  #   - admin    -> can impersonate default + viewer
  #   - superadmin -> can impersonate default + viewer + admin
  #   - ultraadmin -> can impersonate default + viewer + admin + superadmin
  #   - nobody can impersonate ultraadmin
  #   - nobody can impersonate themselves
  def impersonate?
    # Gate on `admin?` (not `any_admin?`): viewer is a read-only tier and
    # must not be able to take over another user's session. The cascade
    # below assumes the actor is at least `admin`.
    return false unless admin?
    return false if record == user
    return false if record.admin_level_ultraadmin?
    return false if record.admin_level_superadmin? && !ultraadmin?
    return false if record.admin_level_admin? && !superadmin?

    true
  end

  # Whether `user` may change `record`'s admin level.
  # Self-edit is always blocked. Granting `ultraadmin` is ultraadmin-only.
  # An ultraadmin's level may only be modified by another ultraadmin —
  # otherwise a superadmin could strip the higher tier of its privileges,
  # violating the ultraadmin ⊇ superadmin invariant.
  # Used by both web `Admin::AdminUsersController#update` and the API
  # `Api::Admin::V1::PermissionsController#update`.
  def change_admin_level?
    superadmin? && record != user && !ultraadmin_target_shielded?
  end

  # May `user` grant the `ultraadmin` role to `record`?
  # Required addition to `change_admin_level?` when the new level is
  # `ultraadmin`.
  def grant_ultraadmin?
    ultraadmin? && record != user
  end

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

  # Superadmins (and ultraadmins) skip the remote-import cooldown for
  # debugging.
  def skip_import_cooldown?
    superadmin?
  end

  private

  # True when `record` is an ultraadmin and the actor is not — used to
  # protect the top tier from sideways privilege manipulation by lower
  # tiers (admin demoting trust, superadmin convicting, etc).
  def ultraadmin_target_shielded?
    record.respond_to?(:admin_level_ultraadmin?) &&
      record.admin_level_ultraadmin? &&
      !ultraadmin?
  end
end
