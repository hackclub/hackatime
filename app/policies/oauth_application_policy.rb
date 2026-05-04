# frozen_string_literal: true

# Admin-side management of every OAuth application in the system.
# Owner-side actions (a user managing their own apps) live in the
# Doorkeeper controller and don't go through this policy.
class OauthApplicationPolicy < ApplicationPolicy
  def index?  = superadmin?
  def show?   = superadmin?
  def edit?   = superadmin?
  def update? = superadmin?

  def toggle_verified? = superadmin?
  def rotate_secret?   = superadmin?
end
