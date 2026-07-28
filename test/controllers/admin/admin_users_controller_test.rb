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

  test "index does not offer superadmins controls for ultraadmins" do
    get admin_admin_users_path

    assert_response :success
    assert_select "form[action=?]", admin_admin_user_path(@ultraadmin, admin_level: "superadmin"), count: 0
    assert_select "form[action=?]", admin_admin_user_path(@ultraadmin, admin_level: "default"), count: 0
    assert_select "th", text: "Actions", count: 1
  end

  test "search does not offer superadmins controls for ultraadmins" do
    get search_admin_admin_users_path, params: { q: @ultraadmin.username }

    assert_response :success
    assert_select "form[action^=?]", admin_admin_user_path(@ultraadmin), count: 0
  end
end
