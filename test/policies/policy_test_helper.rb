# frozen_string_literal: true

require "test_helper"

# Shared helpers for policy tests. Builds one user per role with
# `User.create!` (the `users` fixture is excluded from auto-load) and
# memoizes them per-test-instance so a single test class instantiates
# each role only once.
module PolicyTestHelper
  ROLES = %i[default viewer admin superadmin ultraadmin].freeze

  def user_with(admin_level:, trust_level: :blue)
    User.create!(timezone: "UTC", admin_level: admin_level, trust_level: trust_level)
  end

  # Build the policy-under-test for a role, against an optional record.
  # Subclasses set `policy_class` (or override #policy directly).
  def policy_for(role, record = nil)
    user = users_by_role[role]
    klass = self.class.policy_class
    klass.new(user, record)
  end

  def users_by_role
    @users_by_role ||= ROLES.each_with_object({}) do |role, h|
      h[role] = user_with(admin_level: role)
    end
  end

  def red_user(admin_level: :default)
    @red_user ||= {}
    @red_user[admin_level] ||= user_with(admin_level: admin_level, trust_level: :red)
  end
end

class PolicyTestCase < ActiveSupport::TestCase
  include PolicyTestHelper

  class << self
    attr_accessor :policy_class
  end
end
