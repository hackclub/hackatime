# frozen_string_literal: true

# Trust-level audit logs are read-only and visible to anyone in the admin
# chain (including viewer).
class TrustLevelAuditLogPolicy < ApplicationPolicy
  def index? = viewer?
  def show?  = viewer?
end
