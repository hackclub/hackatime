# frozen_string_literal: true

require_relative "policy_test_helper"

class AdminUserPolicyTest < PolicyTestCase
  self.policy_class = AdminUserPolicy

  test "index? and search? require superadmin and above" do
    %i[index? search?].each do |action|
      results = ROLES.index_with { |r| policy_for(r).public_send(action) }
      expected = { default: false, viewer: false, admin: false, superadmin: true, ultraadmin: true }
      assert_equal expected, results
    end
  end
end
