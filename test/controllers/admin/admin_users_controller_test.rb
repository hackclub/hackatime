require "test_helper"

class Admin::AdminUsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @superadmin = User.create!(timezone: "UTC", admin_level: :superadmin, username: "admin_manager")
    @ultraadmin = User.create!(timezone: "UTC", admin_level: :ultraadmin, username: "protected_ultraadmin")
    User.create!(timezone: "UTC", admin_level: :admin, username: "manageable_admin")
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
    ultraadmin = inertia_page.dig("props", "groups", "ultraadmin").find { |user| user["id"] == @ultraadmin.id }

    assert_empty ultraadmin["allowed_levels"]
  end

  test "search reload returns only authorised search results" do
    get admin_admin_users_path

    assert_nil inertia_page.dig("props", "search_results")

    get admin_admin_users_path, params: { q: @ultraadmin.username }, headers: {
      "X-Inertia" => "true",
      "X-Requested-With" => "XMLHttpRequest",
      "X-Inertia-Version" => inertia_page["version"],
      "X-Inertia-Partial-Component" => "Admin/AdminUsers",
      "X-Inertia-Partial-Data" => "search_results"
    }

    assert_response :success
    props = response.parsed_body.fetch("props")
    ultraadmin = props.dig("search_results", "users").find { |user| user["id"] == @ultraadmin.id }

    assert_nil props["groups"]
    assert_equal @ultraadmin.username, props.dig("search_results", "query")
    assert_empty ultraadmin["allowed_levels"]
  end
end
