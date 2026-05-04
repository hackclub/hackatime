# frozen_string_literal: true

require_relative "policy_test_helper"

class TrustLevelAuditLogPolicyTest < PolicyTestCase
  self.policy_class = TrustLevelAuditLogPolicy

  test "index? and show? require viewer and above" do
    %i[index? show?].each do |action|
      results = ROLES.index_with { |r| policy_for(r).public_send(action) }
      expected = { default: false, viewer: true, admin: true, superadmin: true, ultraadmin: true }
      assert_equal expected, results
    end
  end
end
