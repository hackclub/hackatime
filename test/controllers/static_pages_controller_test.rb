require "test_helper"

class StaticPagesControllerTest < ActionDispatch::IntegrationTest
  test "signed in homepage shares app layout props" do
    user = User.create!
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_inertia_component "Home/SignedIn"
    assert_not_nil inertia_page.dig("props", "layout")
  end
end
