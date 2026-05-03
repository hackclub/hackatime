# frozen_string_literal: true

require_relative "policy_test_helper"

class UserPolicyTest < PolicyTestCase
  self.policy_class = UserPolicy

  setup do
    @target = user_with(admin_level: :default)
  end

  # ---- update_trust_level? (non-red trust changes) ----

  test "update_trust_level? requires admin and above, blocks self" do
    assert_equal({ default: false, viewer: false, admin: true, superadmin: true, ultraadmin: true },
                 ROLES.index_with { |r| UserPolicy.new(users_by_role[r], @target).update_trust_level? })
  end

  test "update_trust_level? blocks self-edit" do
    %i[admin superadmin ultraadmin].each do |role|
      actor = users_by_role[role]
      refute UserPolicy.new(actor, actor).update_trust_level?, "#{role} should not be able to change own trust"
    end
  end

  # ---- convict? (set trust to red) ----

  test "convict? requires superadmin or ultraadmin" do
    assert_equal({ default: false, viewer: false, admin: false, superadmin: true, ultraadmin: true },
                 ROLES.index_with { |r| UserPolicy.new(users_by_role[r], @target).convict? })
  end

  test "convict? blocks self-conviction" do
    %i[superadmin ultraadmin].each do |role|
      actor = users_by_role[role]
      refute UserPolicy.new(actor, actor).convict?
    end
  end

  # ---- impersonate? ----

  test "impersonate? — default actor cannot impersonate anyone" do
    actor = users_by_role[:default]
    ROLES.each do |role|
      refute UserPolicy.new(actor, users_by_role[role]).impersonate?
    end
  end

  test "impersonate? — admin can impersonate default and viewer only" do
    actor = users_by_role[:admin]
    expectations = { default: true, viewer: true, admin: false, superadmin: false, ultraadmin: false }
    actual = ROLES.index_with { |r| UserPolicy.new(actor, users_by_role[r]).impersonate? }
    # Self check: an admin impersonating themselves is blocked
    actual[:admin] = UserPolicy.new(actor, user_with(admin_level: :admin)).impersonate?
    assert_equal expectations, actual
  end

  test "impersonate? — superadmin can impersonate default, viewer, admin (not super or ultra)" do
    actor = users_by_role[:superadmin]
    expectations = { default: true, viewer: true, admin: true, superadmin: false, ultraadmin: false }
    actual = ROLES.index_with { |r| UserPolicy.new(actor, users_by_role[r]).impersonate? }
    actual[:superadmin] = UserPolicy.new(actor, user_with(admin_level: :superadmin)).impersonate?
    assert_equal expectations, actual
  end

  test "impersonate? — ultraadmin can impersonate everyone except other ultraadmins" do
    actor = users_by_role[:ultraadmin]
    expectations = { default: true, viewer: true, admin: true, superadmin: true, ultraadmin: false }
    actual = ROLES.index_with { |r| UserPolicy.new(actor, users_by_role[r]).impersonate? }
    actual[:ultraadmin] = UserPolicy.new(actor, user_with(admin_level: :ultraadmin)).impersonate?
    assert_equal expectations, actual
  end

  test "impersonate? blocks impersonating self" do
    %i[admin superadmin ultraadmin].each do |role|
      actor = users_by_role[role]
      refute UserPolicy.new(actor, actor).impersonate?
    end
  end

  # ---- change_admin_level? ----

  test "change_admin_level? requires superadmin and above, blocks self" do
    assert_equal({ default: false, viewer: false, admin: false, superadmin: true, ultraadmin: true },
                 ROLES.index_with { |r| UserPolicy.new(users_by_role[r], @target).change_admin_level? })
  end

  test "change_admin_level? blocks self-edit (regression for API bug)" do
    %i[superadmin ultraadmin].each do |role|
      actor = users_by_role[role]
      refute UserPolicy.new(actor, actor).change_admin_level?
    end
  end

  # ---- grant_ultraadmin? ----

  test "grant_ultraadmin? requires ultraadmin actor" do
    assert_equal({ default: false, viewer: false, admin: false, superadmin: false, ultraadmin: true },
                 ROLES.index_with { |r| UserPolicy.new(users_by_role[r], @target).grant_ultraadmin? })
  end

  test "grant_ultraadmin? blocks self-grant" do
    actor = users_by_role[:ultraadmin]
    refute UserPolicy.new(actor, actor).grant_ultraadmin?
  end

  # ---- API soft-ban predicates ----

  test "use_authenticated_api? is true for any signed-in non-red user" do
    ROLES.each do |role|
      actor = users_by_role[role]
      assert UserPolicy.new(actor, actor).use_authenticated_api?, "#{role} should have API access"
    end
  end

  test "use_authenticated_api? is false for red users" do
    actor = red_user
    refute UserPolicy.new(actor, actor).use_authenticated_api?
  end

  test "use_authenticated_api? is false for nil user" do
    refute UserPolicy.new(nil, nil).use_authenticated_api?
  end

  test "export_heartbeats? mirrors use_authenticated_api?" do
    actor = users_by_role[:default]
    assert UserPolicy.new(actor, actor).export_heartbeats?
    refute UserPolicy.new(red_user, red_user).export_heartbeats?
  end

  # ---- skip_import_cooldown? ----

  test "skip_import_cooldown? requires superadmin and above" do
    assert_equal({ default: false, viewer: false, admin: false, superadmin: true, ultraadmin: true },
                 ROLES.index_with { |r| UserPolicy.new(users_by_role[r], users_by_role[r]).skip_import_cooldown? })
  end
end
