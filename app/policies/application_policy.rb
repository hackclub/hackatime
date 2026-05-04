# frozen_string_literal: true

# Base policy with the canonical role hierarchy.
#
# Strict linear cascade: ultraadmin >= superadmin >= admin >= viewer >= default.
# Subclass policies should call these predicates instead of touching
# `user.admin_level_*?` directly so the hierarchy stays in one place.
#
# Example:
#   class WidgetPolicy < ApplicationPolicy
#     def destroy? = superadmin?
#   end
#
# `record` is whatever Pundit was given (an AR instance, a class, or a symbol
# for "headless" policies).
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def ultraadmin?
    !!user&.admin_level_ultraadmin?
  end

  def superadmin?
    ultraadmin? || !!user&.admin_level_superadmin?
  end

  def admin?
    superadmin? || !!user&.admin_level_admin?
  end

  def viewer?
    admin? || !!user&.admin_level_viewer?
  end

  # Any non-default tier (admin/superadmin/viewer/ultraadmin).
  def any_admin?
    viewer?
  end

  def signed_in?
    user.present?
  end

  def red?
    !!user&.red?
  end

  def index?    = false
  def show?     = false
  def create?   = false
  def new?      = create?
  def update?   = false
  def edit?     = update?
  def destroy?  = false

  # Pundit scope. Default to none so subclasses must opt in.
  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end
  end
end
