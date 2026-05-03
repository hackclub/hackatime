# frozen_string_literal: true

require_relative "policy_test_helper"

class PermissionPolicyTest < PolicyTestCase
  self.policy_class = PermissionPolicy

  test "index? requires superadmin and above" do
    assert_equal({ default: false, viewer: false, admin: false, superadmin: true, ultraadmin: true },
                 ROLES.index_with { |r| policy_for(r).index? })
  end
end
