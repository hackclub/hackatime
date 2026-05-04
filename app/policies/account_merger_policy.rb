# frozen_string_literal: true

# Merging accounts is destructive and ultraadmin-only.
class AccountMergerPolicy < ApplicationPolicy
  def access?        = ultraadmin?
  def search_users?  = ultraadmin?
  def merge?         = ultraadmin?
end
