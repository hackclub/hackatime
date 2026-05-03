# frozen_string_literal: true

require_relative "policy_test_helper"

class AccountMergerPolicyTest < PolicyTestCase
  self.policy_class = AccountMergerPolicy

  test "every action requires ultraadmin" do
    %i[access? search_users? merge?].each do |action|
      results = ROLES.index_with { |r| policy_for(r).public_send(action) }
      expected = { default: false, viewer: false, admin: false, superadmin: false, ultraadmin: true }
      assert_equal expected, results, "expected #{action} -> #{expected}"
    end
  end
end
