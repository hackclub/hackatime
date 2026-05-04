# frozen_string_literal: true

# Admin review timeline. Read-only for anyone in the admin chain
# (including viewer); the per-row "set trust level" affordance is gated
# by UserPolicy#update_trust_level? at the view layer.
class TimelinePolicy < ApplicationPolicy
  def show?               = viewer?
  def search_users?       = viewer?
  def leaderboard_users?  = viewer?
end
