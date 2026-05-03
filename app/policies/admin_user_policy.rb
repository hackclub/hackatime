# frozen_string_literal: true

# Admin::AdminUsersController (the role-management UI).
# Listing is superadmin+. Per-row updates are gated separately via
# UserPolicy#change_admin_level? / #grant_ultraadmin?.
class AdminUserPolicy < ApplicationPolicy
  def index?  = superadmin?
  def search? = superadmin?
end
