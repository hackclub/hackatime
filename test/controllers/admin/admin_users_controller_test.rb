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

  test "translated admin navigation uses Inertia links" do
    get admin_admin_users_path

    links = inertia_page.dig("props", "layout", "nav").values_at("admin_links", "superadmin_links").flatten
    translated_labels = [ "Trust Level Logs", "Admin Management", "Account Deletions", "All OAuth Apps" ]

    assert translated_labels.all? { |label| links.find { |link| link["label"] == label }.fetch("inertia") }
  end

  test "search does not offer superadmins actions for ultraadmins" do
    get search_admin_admin_users_path, params: { q: @ultraadmin.username }

    assert_response :success
    ultraadmin = response.parsed_body.fetch("users").find { |user| user["id"] == @ultraadmin.id }

    assert_empty ultraadmin["allowed_levels"]
  end
end
