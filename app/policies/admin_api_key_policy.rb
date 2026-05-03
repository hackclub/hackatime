# frozen_string_literal: true

# Admin API keys.
#   - viewer & up may list and read.
#   - admin  & up may mint and revoke (write actions).
class AdminApiKeyPolicy < ApplicationPolicy
  def index?   = viewer?
  def show?   = viewer?

  def new?     = admin?
  def create?  = admin?
  def destroy? = admin?
end
