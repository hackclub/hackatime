# frozen_string_literal: true

require_relative "policy_test_helper"

class AdminPolicyTest < PolicyTestCase
  self.policy_class = AdminPolicy

  test "access? requires any admin tier" do
    assert_equal({ default: false, viewer: true, admin: true, superadmin: true, ultraadmin: true },
                 ROLES.index_with { |r| policy_for(r).access? })
  end

  test "mini_profiler? is admin and above (excludes viewer)" do
    assert_equal({ default: false, viewer: false, admin: true, superadmin: true, ultraadmin: true },
                 ROLES.index_with { |r| policy_for(r).mini_profiler? })
  end

  test "access? is false for nil user" do
    refute AdminPolicy.new(nil, :admin).access?
  end
end
