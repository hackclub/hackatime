require "test_helper"

class Admin::AdminUsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @superadmin = create(:user, :superadmin, username: "admin_manager")
    @ultraadmin = create(:user, :ultraadmin, username: "protected_ultraadmin")
    create(:user, :admin, username: "manageable_admin")
    sign_in_as(@superadmin)
  end

  test "superadmin cannot demote an ultraadmin" do
    patch admin_admin_user_path(@ultraadmin), params: { admin_level: "superadmin" }

    assert_redirected_to admin_admin_users_path
    assert_equal "Only ultraadmins can change an ultraadmin's role.", flash[:alert]
    assert_equal "ultraadmin", @ultraadmin.reload.admin_level
  end

  test "index does not offer superadmins actions for ultraadmins" do
    get admin_admin_users_path

    assert_response :success
    assert_inertia_component "Admin/AdminUsers"
    ultraadmin = inertia.props.dig("groups", "ultraadmin").find { |user| user["id"] == @ultraadmin.id }

    assert_empty ultraadmin["allowed_levels"]
  end

  test "index lists each admin's active API keys with last use" do
    admin = User.find_by!(username: "manageable_admin")
    used = create(:admin_api_key, user: admin, name: "Used key")
    used.update_columns(last_used_at: Time.utc(2026, 11, 1, 23, 21, 31))
    create(:admin_api_key, user: admin, name: "Unused key")
    create(:admin_api_key, user: admin, name: "Old key").revoke!

    get admin_admin_users_path

    assert_response :success
    keys = inertia.props.dig("groups", "admin").find { |user| user["id"] == admin.id }["admin_api_keys"]
    assert_equal [ "Used key", "Unused key" ], keys.map { |key| key["name"] }
    assert_equal "Nov 01, 2026 at 11:21 PM UTC", keys.first["last_used_at"]
    assert_nil keys.second["last_used_at"]
    assert keys.all? { |key| key["token_preview"].end_with?("...") }
  end

  test "index loads admin API keys without a query per admin" do
    create_list(:user, 3, :admin).each { |admin| create(:admin_api_key, user: admin) }
    key_queries = 0
    counter = ->(*, payload) { key_queries += 1 if payload[:sql].include?(%("admin_api_keys")) }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get admin_admin_users_path }

    assert_response :success
    assert_equal 1, key_queries
  end

  test "search reload returns only authorised search results" do
    get admin_admin_users_path

    assert_nil inertia.props["search_results"]
    get admin_admin_users_path(q: @ultraadmin.username)
    inertia_reload_only :search_results

    assert_response :success
    props = inertia.props
    ultraadmin = props.dig("search_results", "users").find { |user| user["id"] == @ultraadmin.id }

    assert_nil props["groups"]
    assert_equal @ultraadmin.username, props.dig("search_results", "query")
    assert_empty ultraadmin["allowed_levels"]
  end
end
