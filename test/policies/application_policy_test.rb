# frozen_string_literal: true

require_relative "policy_test_helper"

class ApplicationPolicyTest < PolicyTestCase
  self.policy_class = ApplicationPolicy

  test "ultraadmin? is true only for ultraadmin" do
    assert_equal({ default: false, viewer: false, admin: false, superadmin: false, ultraadmin: true },
                 role_results(:ultraadmin?))
  end

  test "superadmin? is true for superadmin and ultraadmin" do
    assert_equal({ default: false, viewer: false, admin: false, superadmin: true, ultraadmin: true },
                 role_results(:superadmin?))
  end

  test "admin? is true for admin, superadmin, and ultraadmin" do
    assert_equal({ default: false, viewer: false, admin: true, superadmin: true, ultraadmin: true },
                 role_results(:admin?))
  end

  test "viewer? is true for viewer and above" do
    assert_equal({ default: false, viewer: true, admin: true, superadmin: true, ultraadmin: true },
                 role_results(:viewer?))
  end

  test "any_admin? is the same as viewer?" do
    ROLES.each do |role|
      p = policy_for(role)
      assert_equal p.viewer?, p.any_admin?, "any_admin?/viewer? mismatch for #{role}"
    end
  end

  test "signed_in? is false for nil user" do
    refute ApplicationPolicy.new(nil, nil).signed_in?
  end

  test "red? reflects user trust_level" do
    assert ApplicationPolicy.new(red_user, nil).red?
    refute policy_for(:default).red?
  end

  private

  def role_results(predicate)
    ROLES.index_with { |role| policy_for(role).public_send(predicate) }
  end
end
