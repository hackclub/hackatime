# frozen_string_literal: true

require_relative "policy_test_helper"

class DeletionRequestPolicyTest < PolicyTestCase
  self.policy_class = DeletionRequestPolicy

  test "every action requires superadmin and above" do
    %i[index? show? approve? reject?].each do |action|
      results = ROLES.index_with { |r| policy_for(r).public_send(action) }
      expected = { default: false, viewer: false, admin: false, superadmin: true, ultraadmin: true }
      assert_equal expected, results, "expected #{action} -> #{expected}"
    end
  end
end
