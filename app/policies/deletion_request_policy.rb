# frozen_string_literal: true

# Account deletion requests can only be reviewed/approved/rejected by
# superadmins (and ultraadmins via the hierarchy cascade).
class DeletionRequestPolicy < ApplicationPolicy
  def index?   = superadmin?
  def show?    = superadmin?
  def approve? = superadmin?
  def reject?  = superadmin?
end
