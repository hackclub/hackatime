# frozen_string_literal: true

require_relative "policy_test_helper"

class TimelinePolicyTest < PolicyTestCase
  self.policy_class = TimelinePolicy

  test "all timeline actions require viewer and above" do
    %i[show? search_users? leaderboard_users?].each do |action|
      results = ROLES.index_with { |r| policy_for(r).public_send(action) }
      expected = { default: false, viewer: true, admin: true, superadmin: true, ultraadmin: true }
      assert_equal expected, results
    end
  end
end
