# frozen_string_literal: true

require_relative "policy_test_helper"

class OauthApplicationPolicyTest < PolicyTestCase
  self.policy_class = OauthApplicationPolicy

  test "every admin action requires superadmin and above" do
    %i[index? show? edit? update? toggle_verified? rotate_secret?].each do |action|
      results = ROLES.index_with { |r| policy_for(r).public_send(action) }
      expected = { default: false, viewer: false, admin: false, superadmin: true, ultraadmin: true }
      assert_equal expected, results, "expected #{action} -> #{expected}"
    end
  end
end
