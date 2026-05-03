# frozen_string_literal: true

# Used by the API permissions endpoint (Api::Admin::V1::PermissionsController).
# The actual record-level decision (who can change *whom*) is delegated
# to UserPolicy; this policy only gates listing.
class PermissionPolicy < ApplicationPolicy
  def index?
    superadmin?
  end
end
